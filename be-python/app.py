from flask import Flask, request, jsonify, send_from_directory
from flask_sqlalchemy import SQLAlchemy
import os
import uuid
from datetime import datetime
from werkzeug.utils import secure_filename
from dotenv import load_dotenv
import whisper
import logging
from flask_ngrok import run_with_ngrok
from flask_cors import CORS
from flask_migrate import Migrate
import requests

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
run_with_ngrok(app)
CORS(app)

# Database configuration
db_dir = os.path.join(os.path.dirname(__file__), 'data')  # Path to 'data' directory

if not os.path.exists(db_dir):
    os.makedirs(db_dir)

app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(db_dir, 'chatbot.db')}"
db = SQLAlchemy(app)
migrate = Migrate(app, db)

# API Keys
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")

# Helper function for upload folders
def get_upload_folder(device_id, file_type):
    base_folder = os.path.join('uploads', device_id, file_type)
    os.makedirs(base_folder, exist_ok=True)
    return base_folder

# Database Models
class Session(db.Model):
    __tablename__ = 'sessions'
    id = db.Column(db.String(36), primary_key=True)
    device_id = db.Column(db.String(255), nullable=False, index=True)  # Pastikan kolom ini ada
    name = db.Column(db.String(100), nullable=False)
    created_at = db.Column(db.BigInteger, nullable=False)
    updated_at = db.Column(db.BigInteger, nullable=False)
    messages = db.relationship('Message', backref='session', lazy=True, cascade='all, delete-orphan')

class Message(db.Model):
    __tablename__ = 'messages'
    
    id = db.Column(db.String(36), primary_key=True)
    session_id = db.Column(db.String(36), db.ForeignKey('sessions.id'), nullable=False)
    device_id = db.Column(db.String(255), nullable=False, index=True)
    content = db.Column(db.Text, nullable=False)
    role = db.Column(db.String(20), nullable=False)
    timestamp = db.Column(db.BigInteger, nullable=False)
    image_path = db.Column(db.String(255), nullable=True)
    audio_path = db.Column(db.String(255), nullable=True)

# Initialize database
with app.app_context():
    db.create_all()

# Whisper model initialization
try:
    WHISPER_MODEL = whisper.load_model("base")
    logging.info("Whisper model loaded successfully")
except Exception as e:
    logging.error(f"Failed to load Whisper model: {e}")
    WHISPER_MODEL = None

@app.route('/')
def home():
    return jsonify({"status": "Flask is running!"})

@app.route('/api/device', methods=['POST'])
def register_device():
    device_id = request.json.get('device_id')
    if not device_id:
        return jsonify({"error": "Device ID is required"}), 400
    return jsonify({"status": "success", "device_id": device_id})

# Add proper error handling to all endpoints
@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Resource not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal server error"}), 500
# Session Endpoints

@app.route('/api/sessions', methods=['GET'])
def get_sessions():
    device_id = request.args.get('device_id')
    if not device_id:
        return jsonify({"error": "Device ID is required"}), 400
    sessions = Session.query.filter_by(device_id=device_id).order_by(Session.updated_at.desc()).all()
    return jsonify([{
        "id": session.id,
        "name": session.name,
        "created_at": session.created_at,
        "updated_at": session.updated_at
    } for session in sessions])

@app.route('/api/sessions', methods=['POST'])
def create_session():
    try:
        data = request.json
        name = data.get('name', 'New Chat')
        device_id = data.get('device_id')
        
        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
            
        session_id = str(uuid.uuid4())
        current_time = int(datetime.now().timestamp() * 1000)
        
        new_session = Session(
            id=session_id,
            device_id=device_id,
            name=name,
            created_at=current_time,
            updated_at=current_time
        )
        
        db.session.add(new_session)
        db.session.commit()
        
        return jsonify({
            "id": session_id,
            "name": name,
            "created_at": current_time,
            "updated_at": current_time
        })
        
    except Exception as e:
        logger.error(f"Error creating session: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to create session"}), 500

@app.route('/api/sessions/<session_id>', methods=['GET'])
def get_session_by_id(session_id):
    try:
        device_id = request.args.get('device_id')
        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
            
        session = Session.query.filter_by(id=session_id, device_id=device_id).first()
        if not session:
            return jsonify({"error": "Session not found"}), 404

        messages = Message.query.filter_by(session_id=session_id, device_id=device_id).order_by(Message.timestamp.asc()).all()

        message_list = [{
            "id": msg.id,
            "session_id": msg.session_id,
            "content": msg.content,
            "role": msg.role,
            "timestamp": msg.timestamp,
            "image_path": msg.image_path,
            "audio_path": msg.audio_path
        } for msg in messages]

        return jsonify({
            "session_id": session.id,
            "name": session.name,
            "messages": message_list
        })

    except Exception as e:
        logger.error(f"Error getting session by ID: {e}")
        return jsonify({"error": "Failed to get session data"}), 500

@app.route('/api/sessions/<session_id>', methods=['PUT'])
def update_session(session_id):
    try:
        device_id = request.json.get('device_id')
        name = request.json.get('name')
        
        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
        if not name:
            return jsonify({"error": "Name is required"}), 400
        
        session = Session.query.filter_by(id=session_id, device_id=device_id).first()
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        current_time = int(datetime.now().timestamp() * 1000)
        session.name = name
        session.updated_at = current_time
        
        db.session.commit()
        
        return jsonify({"message": "Session updated successfully"})
    except Exception as e:
        logger.error(f"Error updating session: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to update session"}), 500

@app.route('/api/sessions/<session_id>', methods=['DELETE'])
def delete_session(session_id):
    try:
        device_id = request.args.get('device_id')
        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
            
        session = Session.query.filter_by(id=session_id, device_id=device_id).first()
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        db.session.delete(session)
        db.session.commit()
        
        return jsonify({"message": "Session deleted successfully"})
    except Exception as e:
        logger.error(f"Error deleting session: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to delete session"}), 500

# Message Endpoints
@app.route('/api/sessions/<session_id>/messages', methods=['GET'])
def get_messages(session_id):
    device_id = request.args.get('device_id')
    if not device_id:
        return jsonify({"error": "Device ID is required"}), 400
    messages = Message.query.filter_by(
        session_id=session_id, 
        device_id=device_id
    ).order_by(Message.timestamp.asc()).all()
    
    return jsonify([{
        "id": msg.id,
        "session_id": msg.session_id,
        "content": msg.content,
        "role": msg.role,
        "timestamp": msg.timestamp,
        "image_path": msg.image_path,
        "audio_path": msg.audio_path
    } for msg in messages])

@app.route('/api/sessions/<session_id>/messages', methods=['POST'])
def save_message(session_id):
    try:
        data = request.json
        device_id = data.get('device_id')
        
        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
            
        if not data or 'content' not in data or 'role' not in data:
            return jsonify({"error": "Missing required fields"}), 400
            
        session = Session.query.filter_by(id=session_id, device_id=device_id).first()
        if not session:
            return jsonify({"error": "Session not found"}), 404
            
        message = Message(
            id=str(uuid.uuid4()),
            session_id=session_id,
            device_id=device_id,
            content=data['content'],
            role=data['role'],
            timestamp=int(datetime.now().timestamp() * 1000),
            image_path=data.get('image_path'),
            audio_path=data.get('audio_path')
        )
        
        session.updated_at = int(datetime.now().timestamp() * 1000)
        db.session.add(message)
        db.session.commit()
        
        return jsonify({
            "id": message.id,
            "session_id": session_id,
            "content": message.content,
            "role": message.role,
            "timestamp": message.timestamp,
            "image_path": message.image_path,
            "audio_path": message.audio_path
        }), 201
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Error saving message: {str(e)}")
        return jsonify({"error": "Failed to save message", "details": str(e)}), 500

@app.route('/api/sessions/<session_id>/messages', methods=['DELETE'])
def clear_messages(session_id):
    try:
        device_id = request.args.get('device_id')
        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
            
        Message.query.filter_by(session_id=session_id, device_id=device_id).delete()
        db.session.commit()
        
        return jsonify({"message": "All messages cleared successfully"})
    except Exception as e:
        logger.error(f"Error clearing messages: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to clear messages"}), 500

@app.route('/api/sessions/<session_id>/messages/<message_id>', methods=['DELETE'])
def delete_message(session_id, message_id):
    try:
        device_id = request.args.get('device_id')
        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
            
        message = Message.query.filter_by(
            id=message_id, 
            session_id=session_id,
            device_id=device_id
        ).first()
        
        if not message:
            return jsonify({"error": "Message not found"}), 404
        
        db.session.delete(message)
        db.session.commit()
        
        return jsonify({"message": "Message deleted successfully"})
    except Exception as e:
        logger.error(f"Error deleting message: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to delete message"}), 500

# File Upload Endpoints
@app.route('/api/upload/audio', methods=['POST'])
def upload_audio():
    if 'audio' not in request.files:
        return jsonify({"error": "No audio file provided"}), 400

    device_id = request.form.get('device_id')
    if not device_id:
        return jsonify({"error": "Device ID is required"}), 400

    audio_file = request.files['audio']
    if audio_file.filename == '':
        return jsonify({"error": "Empty filename"}), 400

    try:
        upload_folder = get_upload_folder(device_id, 'audio')
        filename = f"audio_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.wav"
        filepath = os.path.join(upload_folder, filename)
        audio_file.save(filepath)

        return jsonify({
            "status": "success",
            "file_url": f"/uploads/{device_id}/audio/{filename}"
        })

    except Exception as e:
        logger.error(f"Audio upload error: {str(e)}")
        return jsonify({"error": "Audio upload failed"}), 500

@app.route('/api/upload/image', methods=['POST'])
def upload_image():
    if 'image' not in request.files:
        return jsonify({"error": "No image file provided"}), 400

    device_id = request.form.get('device_id')
    if not device_id:
        return jsonify({"error": "Device ID is required"}), 400

    image_file = request.files['image']
    if image_file.filename == '':
        return jsonify({"error": "Empty filename"}), 400

    try:
        upload_folder = get_upload_folder(device_id, 'images')
        filename = secure_filename(f"img_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.{image_file.filename.split('.')[-1].lower()}")
        filepath = os.path.join(upload_folder, filename)
        image_file.save(filepath)

        return jsonify({
            "status": "success",
            "file_url": f"/uploads/{device_id}/images/{filename}"
        })

    except Exception as e:
        logger.error(f"Image upload error: {str(e)}")
        return jsonify({"error": "Image upload failed"}), 500
    
# File Serving Endpoints
@app.route('/uploads/<device_id>/audio/<filename>')
def serve_audio(device_id, filename):
    return send_from_directory(get_upload_folder(device_id, 'audio'), filename)

@app.route('/uploads/<device_id>/images/<filename>')
def serve_image(device_id, filename):
    return send_from_directory(get_upload_folder(device_id, 'images'), filename)

@app.route('/api/vision', methods=['POST'])
def analyze_image():
    try:
        if 'image' not in request.files:
            return jsonify({"error": "No image file provided"}), 400

        device_id = request.form.get('device_id')
        session_id = request.form.get('session_id')
        prompt = request.form.get('prompt', 'Analisis gambar tanaman ini dan berikan informasi tentang kondisinya.')

        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400

        image_file = request.files['image']
        if image_file.filename == '':
            return jsonify({"error": "Empty filename"}), 400

        # Save the image file
        upload_folder = get_upload_folder(device_id, 'images')
        filename = secure_filename(f"img_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.{image_file.filename.split('.')[-1].lower()}")
        filepath = os.path.join(upload_folder, filename)
        image_file.save(filepath)

        # Convert image to base64 for DeepSeek API
        with open(filepath, "rb") as img_file:
            img_base64 = base64.b64encode(img_file.read()).decode('utf-8')

        # Send to DeepSeek API for analysis
        headers = {
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json"
        }

        payload = {
            "model": "deepseek-vision",
            "messages": [
                {
                    "role": "system", 
                    "content": """Anda adalah Asisten Pertanian PeTaniku yang ahli menganalisis gambar tanaman.
Berikan analisis detail tentang:
- Jenis tanaman yang terlihat
- Kondisi kesehatan tanaman
- Kemungkinan masalah atau penyakit
- Saran perawatan atau penanganan

Gunakan bahasa yang sederhana dan praktis untuk petani Indonesia."""
                },
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_base64}"}}
                    ]
                }
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        }

        response = requests.post(
            "https://api.deepseek.com/v1/chat/completions",
            headers=headers,
            json=payload
        )

        result = response.json()

        if response.status_code == 200:
            analysis = result['choices'][0]['message']['content']

            # Save messages to database
            current_time = int(datetime.now().timestamp() * 1000)
            
            # Save user message with image
            user_message = Message(
                id=str(uuid.uuid4()),
                session_id=session_id,
                device_id=device_id,
                content=prompt,
                role='user',
                timestamp=current_time,
                image_path=f"/uploads/{device_id}/images/{filename}"
            )
            
            # Save assistant response
            assistant_message = Message(
                id=str(uuid.uuid4()),
                session_id=session_id,
                device_id=device_id,
                content=analysis,
                role='assistant',
                timestamp=current_time + 1
            )
            
            session = Session.query.filter_by(id=session_id).first()
            if session:
                session.updated_at = current_time
                db.session.add_all([user_message, assistant_message])
                db.session.commit()

            return jsonify({
                "status": "success",
                "analysis": analysis,
                "image_path": f"/uploads/{device_id}/images/{filename}"
            })
        else:
            return jsonify({"error": "Failed to analyze image", "details": result}), 500

    except Exception as e:
        logger.error(f"Image analysis error: {str(e)}")
        return jsonify({"error": "Image analysis failed", "details": str(e)}), 500

@app.route('/api/transcribe', methods=['POST'])
def transcribe_audio():
    try:
        logger.info("Transcribe endpoint called")

        # Ensure audio file is in request
        if 'audio' not in request.files:
            logger.error("No audio file provided")
            return jsonify({"error": "No audio file provided"}), 400

        device_id = request.form.get('device_id')
        session_id = request.form.get('session_id')

        logger.info(f"Transcribe request for device_id: {device_id}, session_id: {session_id}")

        if not device_id:
            logger.warning("Device ID is required but not provided")
            device_id = "unknown_device"

        audio_file = request.files['audio']
        if audio_file.filename == '':
            logger.error("Empty filename")
            return jsonify({"error": "Empty filename"}), 400

        # Save the audio file
        upload_folder = get_upload_folder(device_id, 'audio')
        filename = f"audio_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.wav"
        filepath = os.path.join(upload_folder, filename)

        logger.info(f"Saving audio file to: {filepath}")
        audio_file.save(filepath)

        # Transcribe with Whisper
        if WHISPER_MODEL is None:
            logger.error("Whisper model not available")
            return jsonify({
                "error": "Whisper model not available",
                "transcription": "Maaf, layanan pengenalan suara sedang tidak tersedia.",
                "ai_response": "Silakan coba lagi nanti atau ketik pesan Anda."
            }), 200

        logger.info("Transcribing with Whisper model")
        result = WHISPER_MODEL.transcribe(filepath)
        transcription = result["text"]
        logger.info(f"Transcription result: {transcription}")

        # Save messages to database if session_id is provided
        if session_id:
            current_time = int(datetime.now().timestamp() * 1000)

            user_message = Message(
                id=str(uuid.uuid4()),
                session_id=session_id,
                device_id=device_id,
                content=transcription,
                role='user',
                timestamp=current_time,
                audio_path=f"/uploads/{device_id}/audio/{filename}"
            )

            session = Session.query.filter_by(id=session_id).first()
            if session:
                session.updated_at = current_time
                db.session.add(user_message)
                db.session.commit()

        return jsonify({
            "status": "success",
            "transcription": transcription,
            "audio_path": f"/uploads/{device_id}/audio/{filename}"
        })
    except Exception as e:
        logger.error(f"Transcription error: {str(e)}")
        return jsonify({
            "error": "Audio transcription failed",
            "details": str(e),
            "transcription": "Maaf, saya tidak dapat mengenali suara Anda saat ini.",
            "ai_response": "Silakan coba lagi nanti atau ketik pesan Anda."
        }), 200

# AI Chat Endpoint
@app.route('/api/chat', methods=['POST'])
def chat():
    try:
        data = request.json
        message = data.get('message', '')
        session_id = data.get('session_id', '')
        device_id = data.get('device_id', '')
        
        if not message:
            return jsonify({"error": "Message is required"}), 400
        
        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
        
        # Always create a new session if none provided
        if not session_id:
            new_session = Session(
                id=str(uuid.uuid4()),
                device_id=device_id,
                name=message[:30] if message else "Percakapan Baru",
                created_at=int(datetime.now().timestamp() * 1000),
                updated_at=int(datetime.now().timestamp() * 1000)
            )
            db.session.add(new_session)
            db.session.commit()
            session_id = new_session.id

        headers = {
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {
                    "role": "system", 
                    "content":  """Anda adalah Asisten Pertanian PeTaniku yang ahli di bidang:
- Pertanian dan perkebunan
- Cuaca dan iklim untuk pertanian
- Pengelolaan tanaman dan tanah
- Teknologi pertanian

Bantu pengguna dengan:
1. Berikan jawaban mendetail untuk pertanyaan pertanian
2. Jika pertanyaan di luar topik, jawab dengan sopan:
   "Maaf, saya hanya dapat membantu tentang pertanian. Ada yang bisa saya bantu terkait tanaman, cuaca pertanian, atau hal terkait?"

Gaya respons:
- Gunakan bahasa sederhana dan praktis
- Format jelas dengan paragraf terpisah
- Hindari jargon teknis berlebihan"""                },
                {"role": "user", "content": message}
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        }
        
        response = requests.post(
            "https://api.deepseek.com/v1/chat/completions",
            headers=headers,
            json=payload
        )
        
        result = response.json()
        
        if response.status_code == 200:
            assistant_message = result['choices'][0]['message']['content']
            formatted_message = assistant_message.replace('###', '').replace('**', '*')
            
            # Save messages to database
            current_time = int(datetime.now().timestamp() * 1000)
            
            user_message = Message(
                id=str(uuid.uuid4()),
                session_id=session_id,
                device_id=device_id,
                content=message,
                role='user',
                timestamp=current_time
            )
            
            assistant_message = Message(
                id=str(uuid.uuid4()),
                session_id=session_id,
                device_id=device_id,
                content=formatted_message,
                role='assistant',
                timestamp=current_time + 1
            )
            
            session = Session.query.filter_by(id=session_id, device_id=device_id).first()
            if session:
                session.updated_at = current_time
                db.session.add_all([user_message, assistant_message])
                db.session.commit()
            
            return jsonify({
                "response": formatted_message,
                "session_id": session_id
            })
            
    except Exception as e:
        logger.error(f"Chat error: {e}")
        return jsonify({"error": "Terjadi kesalahan"}), 500

# Weather Endpoint
@app.route('/api/weather', methods=['GET'])
def get_weather():
    try:
        lat = request.args.get('lat', type=float)
        lon = request.args.get('lon', type=float)
        
        if not lat or not lon:
            return jsonify({
                'error': 'Koordinat tidak valid',
                'mock': True,
                'location': 'Lokasi tidak diketahui'
            }), 400

        weather_data = get_openweather_data(lat, lon)
        
        if not weather_data:
            return jsonify({
                'error': 'Gagal mengambil data cuaca',
                'mock': True
            }), 500
        
        return jsonify({
            'temperature': weather_data['main']['temp'],
            'condition': weather_data['weather'][0]['main'],
            'description': weather_data['weather'][0]['description'],
            'advice': get_farming_advice(weather_data['weather'][0]['main'])
        })
        
    except Exception as e:
        logger.error(f"Error in weather endpoint: {e}")
        return jsonify({
            'error': str(e),
            'mock': True
        }), 500

# Helper functions
def get_openweather_data(lat, lon):
    try:
        url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={OPENWEATHER_API_KEY}&units=metric&lang=id"
        response = requests.get(url)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        logger.error(f"OpenWeather API error: {e}")
        return None

def get_farming_advice(weather_main):
    weather_main = weather_main.lower()
    
    if any(x in weather_main for x in ['clear', 'sun']):
        return "Cocok untuk panen atau pengeringan hasil panen"
    elif any(x in weather_main for x in ['cloud', 'fog', 'mist', 'haze']):
        return "Baik untuk menanam bibit atau penyemprotan pestisida"
    elif any(x in weather_main for x in ['rain', 'drizzle', 'shower']):
        return "Hindari pemupukan dan penyemprotan pestisida"
    elif any(x in weather_main for x in ['thunder', 'storm']):
        return "Pastikan drainase lahan baik untuk mencegah genangan"
    else:
        return "Pantau kondisi tanaman secara berkala"

if __name__ == '__main__':
    app.run()
