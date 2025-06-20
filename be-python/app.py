import tempfile
from flask import Flask, json, request, jsonify, send_from_directory
from flask_sqlalchemy import SQLAlchemy
import os
import requests
import uuid
from datetime import datetime
from werkzeug.utils import secure_filename
import subprocess
from dotenv import load_dotenv
import whisper
import logging
from flask_ngrok import run_with_ngrok
from flask_cors import CORS
from flask_migrate import Migrate
import base64
import os
from roboflow import Roboflow
from PIL import Image

# Load environment variables
load_dotenv()

# Konfigurasi logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
run_with_ngrok(app)  # Jalankan dengan ngrok untuk testing
CORS(app)  # Mengizinkan CORS agar API bisa diakses dari frontend

# Database configuration
app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(os.path.dirname(__file__), 'chatbot.db')}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# API Keys
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")
ROBOFLOW_API_KEY = os.getenv("ROBOFLOW_API_KEY")

# Durasi maksimal dan minimal file audio (detik)
MAX_AUDIO_DURATION = 30  # seconds
MIN_AUDIO_DURATION = 0.5  # seconds

# Folder sementara untuk menyimpan file upload
UPLOAD_FOLDER = 'temp_uploads'

# Inisialisasi model dari Roboflow untuk deteksi penyakit tanaman
rf = Roboflow(api_key=ROBOFLOW_API_KEY)
project = rf.workspace("institue-of-southern-punjab").project("sample-ixosm")
model = project.version(1).model

def convert_png_to_jpeg(filepath):
    if not filepath.lower().endswith(".png"):
        return filepath
    try:
        image = Image.open(filepath).convert("RGB")
        new_path = filepath.replace(".png", ".jpg")
        image.save(new_path, "JPEG")
        return new_path
    except Exception as e:
        logger.error(f"Gagal mengonversi gambar PNG: {e}")
        return filepath

# Database Models
class Session(db.Model):
    __tablename__ = 'sessions'
    
    id = db.Column(db.String(36), primary_key=True)
    device_id = db.Column(db.String(255), nullable=False, index=True)
    name = db.Column(db.String(100), nullable=False)
    topic = db.Column(db.String(255), nullable=True)
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
    image_path = db.Column(db.String(255))
    audio_path = db.Column(db.String(255))

migrate = Migrate(app, db)

# Whisper model initialization
try:
    WHISPER_MODEL = whisper.load_model("small")
    logging.info("Whisper model loaded successfully")
except Exception as e:
    logging.error(f"Failed to load Whisper model: {e}")
    WHISPER_MODEL = None

with app.app_context():
    # db.drop_all()  # WARNING: Deletes all data!
    db.create_all()

def get_temp_upload_folder(device_id, file_type):
    temp_folder = os.path.join(tempfile.gettempdir(), device_id, file_type)
    os.makedirs(temp_folder, exist_ok=True)
    return temp_folder

@app.route('/')
def home():
    return jsonify({"status": "Flask is running!"})

# Session management endpoints
@app.route('/api/sessions', methods=['GET'])
def get_sessions():
    try:
        device_id = request.args.get('device_id')
        
        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
        
        sessions = Session.query.filter_by(device_id=device_id).order_by(Session.updated_at.desc()).all()
        
        return jsonify([{
            "id": session.id,
            "name": session.name,
            "device_id": session.device_id,
            "created_at": session.created_at,
            "updated_at": session.updated_at
        } for session in sessions])
    except Exception as e:
        logger.error(f"Error getting sessions: {e}")
        return jsonify({"error": "Failed to get sessions"}), 500

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
            name=name,
            device_id=device_id,  # Simpan device_id
            created_at=current_time,
            updated_at=current_time
        )
        
        db.session.add(new_session)
        db.session.commit()
        
        return jsonify({
            "id": session_id,
            "name": name,
            "device_id": device_id,  # Include device_id in response
            "created_at": current_time,
            "updated_at": current_time
        })
    except Exception as e:
        logger.error(f"Error creating session: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to create session"}), 500

@app.route('/api/sessions/<session_id>', methods=['PUT'])
def update_session(session_id):
    try:
        data = request.json
        name = data.get('name')
        
        if not name:
            return jsonify({"error": "Name is required"}), 400
        
        session = db.session.get(Session, session_id)
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
        session = db.session.get(Session, session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        db.session.delete(session)
        db.session.commit()
        
        return jsonify({"message": "Session deleted successfully"})
    except Exception as e:
        logger.error(f"Error deleting session: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to delete session"}), 500

@app.route('/api/sessions/<session_id>/messages', methods=['GET'])
def get_messages(session_id):
    try:
        device_id = request.args.get('device_id')
        
        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
        
        messages = Message.query.filter_by(session_id=session_id, device_id=device_id)\
                              .order_by(Message.timestamp.asc())\
                              .all()
        
        return jsonify([{
            "id": msg.id,
            "session_id": msg.session_id,
            "content": msg.content,
            "role": msg.role,
            "timestamp": msg.timestamp,
            "image_path": msg.image_path,
            "audio_path": msg.audio_path
        } for msg in messages])
    except Exception as e:
        logger.error(f"Error getting messages: {e}")
        return jsonify({"error": "Failed to get messages"}), 500

@app.route('/api/sessions/<session_id>/messages', methods=['POST'])
def save_message(session_id):
    try:
        data = request.json
        if not data:
            return jsonify({"error": "No data provided"}), 400

        # Validate required fields
        required_fields = ['content', 'role', 'device_id']
        if not all(field in data for field in required_fields):
            return jsonify({"error": f"Missing required fields: {required_fields}"}), 400

        # Get session
        session = db.session.get(Session, session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404

        # Create message
        message = Message(
            id=str(uuid.uuid4()),
            session_id=session_id,
            content=data['content'],
            role=data['role'],
            device_id=data['device_id'],  # Simpan device_id
            timestamp=int(datetime.now().timestamp() * 1000),
            image_path=data.get('image_path'),
            audio_path=data.get('audio_path')
        )

        # Update session
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
        Message.query.filter_by(session_id=session_id).delete()
        db.session.commit()
        
        return jsonify({"message": "All messages cleared successfully"})
    except Exception as e:
        logger.error(f"Error clearing messages: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to clear messages"}), 500

@app.route('/api/weather', methods=['GET'])
def get_weather():
    try:
        lat = request.args.get('lat', type=float)
        lon = request.args.get('lon', type=float)
        is_mock = request.args.get('mock', 'false').lower() == 'true'
        
        if is_mock:
            return jsonify(get_mock_weather_data())
            
        # Get weather data from OpenWeather
        weather_data = get_openweather_data(lat, lon)
        
        if not weather_data:
            return jsonify({
                'error': 'Failed to fetch weather data',
                'mock': True,
                'temperature': 30.0,
                'condition': 'sunny',
                'description': 'Cerah',
                'location': 'Jakarta',
                'advice': 'Cocok untuk panen atau pengeringan hasil panen'
            }), 500
        
        return jsonify({
            'temperature': weather_data['main']['temp'],
            'condition': map_weather_condition(weather_data['weather'][0]['main']),
            'description': weather_data['weather'][0]['description'],
            'location': weather_data.get('name', 'Unknown Location'),
            'advice': get_farming_advice(weather_data['weather'][0]['main'])
        })
        
    except Exception as e:
        logger.error(f"Weather API error: {e}")
        return jsonify({
            'error': str(e),
            'mock': True,
            'temperature': 30.0,
            'condition': 'sunny',
            'description': 'Cerah',
            'location': 'Jakarta',
            'advice': 'Cocok untuk panen atau pengeringan hasil panen'
        }), 500

@app.route('/api/transcribe', methods=['POST'])
def transcribe_audio():
    if 'audio' not in request.files:
        return jsonify({"error": "No audio file provided"}), 400

    audio_file = request.files['audio']
    if audio_file.filename == '':
        return jsonify({"error": "Empty filename"}), 400

    device_id = request.form.get('device_id')
    session_id = request.form.get('session_id')

    if not device_id or not session_id:
        return jsonify({"error": "Device ID and Session ID are required"}), 400

    try:
        temp_folder = get_temp_upload_folder(device_id, 'audio')
        filename = f"audio_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.wav"
        filepath = os.path.join(temp_folder, filename)
        audio_file.save(filepath)

        validation = validate_audio_file(filepath)
        if validation.get('error'):
            return jsonify(validation), 400

        # Deteksi bahasa terlebih dahulu
        audio = whisper.load_audio(filepath)
        audio = whisper.pad_or_trim(audio)
        mel = whisper.log_mel_spectrogram(audio).to(WHISPER_MODEL.device)
        _, probs = WHISPER_MODEL.detect_language(mel)
        detected_lang_code = max(probs, key=probs.get)
        detected_lang_prob = round(probs[detected_lang_code] * 100, 2)

        # Transkripsi dengan asumsi konteks bahasa lokal
        result = WHISPER_MODEL.transcribe(
            filepath,
            language="id",
            task="transcribe",
            initial_prompt="Bahasa Indonesia digunakan di percakapan ini."
        )

        transcription = result.get("text", "").strip()
        if not transcription:
            return jsonify({"error": "No speech detected"}), 400

        # Tambahkan pesan ke database
        message = Message(
            id=str(uuid.uuid4()),
            session_id=session_id,
            device_id=device_id,
            content=transcription,
            role='user',
            timestamp=int(datetime.now().timestamp() * 1000),
            audio_path=f"/uploads/temp/{device_id}/audio/{filename}"
        )
        db.session.add(message)

        session = db.session.get(Session, session_id)
        if session:
            session.updated_at = int(datetime.now().timestamp() * 1000)

        db.session.commit()

        # Jawaban dari DeepSeek
        response_text = get_deepseek_response(
            transcription,
            session_id=session_id,
            device_id=device_id
        )
        assistant_message = Message(
            id=str(uuid.uuid4()),
            session_id=session_id,
            device_id=device_id,
            content=response_text,
            role="assistant",
            timestamp=int(datetime.now().timestamp() * 1000)
        )
        db.session.add(assistant_message)
        db.session.commit()

        return jsonify({
            "status": "success",
            "detected_language": detected_lang_code,
            "language_confidence": detected_lang_prob,
            "transcription": transcription,
            "response": response_text,
            "audio_url": f"/uploads/temp/{device_id}/audio/{filename}"
        })

    except Exception as e:
        logging.error(f"Transcription error: {str(e)}")
        return jsonify({"error": "Audio processing failed"}), 500

def validate_audio_file(filepath):
    """Validasi format dan durasi audio"""
    try:
        # Cek apakah file ada
        if not os.path.exists(filepath):
            return {"error": "File not found"}
            
        # Cek ukuran file minimal (100 bytes)
        if os.path.getsize(filepath) < 100:
            return {"error": "File too small (corrupted?)"}
        
        # Validasi dengan ffprobe
        result = subprocess.run([
            'ffprobe', '-v', 'error',
            '-show_entries', 'stream=codec_type,sample_rate,channels',
            '-of', 'json',
            filepath
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            return {"error": "Invalid audio file", "details": result.stderr}
            
        # Parse output ffprobe
        probe_data = json.loads(result.stdout)
        streams = probe_data.get('streams', [])
        
        if not any(s.get('codec_type') == 'audio' for s in streams):
            return {"error": "No audio stream found"}
            
        # Cek sample rate dan channels
        for stream in streams:
            if stream.get('codec_type') == 'audio':
                if int(stream.get('sample_rate', 0)) < 8000:
                    return {"error": "Sample rate too low (min 8kHz)"}
                if int(stream.get('channels', 0)) < 1:
                    return {"error": "No audio channels"}
                    
        return {"valid": True}
        
        
    except json.JSONDecodeError:
        return {"error": "Invalid JSON response from ffprobe"}
    except Exception as e:
        return {"error": f"Validation error: {str(e)}"}

@app.route("/api/analyze/image", methods=["POST"])
def analyze_image():
    from datetime import datetime
    import uuid
    import tempfile

    device_id = request.form.get("device_id")
    session_id = request.form.get("session_id")
    note = request.form.get("note", "").strip()

    if not device_id:
        return jsonify({"error": "Device ID is required"}), 400

    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    # Simpan file gambar
    file = request.files["file"]
    filename = secure_filename(file.filename)
    folder = os.path.join(tempfile.gettempdir(), device_id, "images")
    os.makedirs(folder, exist_ok=True)
    filepath = os.path.join(folder, filename)
    file.save(filepath)

    filepath = convert_png_to_jpeg(filepath)
    logger.info(f"✅ File disimpan di: {filepath}")
    logger.info(f"📏 Ukuran file: {os.path.getsize(filepath)} bytes")
    logger.info(f"📂 File ada?: {'Ya' if os.path.exists(filepath) else 'Tidak'}")

    try:
        # Jalankan prediksi
        result = model.predict(filepath).json()
        logger.info(f"📊 Hasil prediksi mentah dari Roboflow: {result}")
        predictions = result.get("predictions", [])

        if not predictions:
            explanation = "Tidak terdeteksi penyakit pada gambar tersebut. Pastikan gambar jelas dan fokus pada bagian daun atau tanaman yang bermasalah."
            return jsonify({
                "detected": None,
                "confidence": 0.0,
                "explanation": explanation,
                "image_url": f"/uploads/temp/{device_id}/images/{os.path.basename(filepath)}"
            })

        # Filter prediksi yang valid
        filtered_preds = [p for p in predictions if "confidence" in p and "class" in p]
        if not filtered_preds:
            explanation = "Hasil prediksi tidak lengkap atau tidak valid."
            return jsonify({
                "detected": None,
                "confidence": 0.0,
                "explanation": explanation,
                "image_url": f"/uploads/temp/{device_id}/images/{os.path.basename(filepath)}"
            })

        # Pilih prediksi dengan confidence tertinggi
        top_pred = max(filtered_preds, key=lambda p: p.get("confidence", 0))
        label = top_pred.get("class", "Tidak diketahui")
        confidence = round(top_pred.get("confidence", 0) * 100, 2)

        # Buat prompt untuk LLM
        if note:
            prompt = f"Apa itu penyakit '{label}' pada tanaman dan bagaimana cara mengatasinya? Berikut kondisi tambahan dari pengguna: {note}"
        else:
            prompt = f"Apa itu penyakit '{label}' pada tanaman dan bagaimana cara mengatasinya?"

        explanation = get_deepseek_response(prompt)

        now = int(datetime.now().timestamp() * 1000)
        session = db.session.get(Session, session_id) if session_id else None

        if session:
            # Simpan hanya note + gambar sebagai pesan user
            db.session.add(Message(
                id=str(uuid.uuid4()),
                session_id=session_id,
                device_id=device_id,
                content=note if note else "",
                role="user",
                timestamp=now,
                image_path=f"/uploads/temp/{device_id}/images/{os.path.basename(filepath)}"
            ))

            # Simpan respons LLM jika belum duplikat
            existing = db.session.query(Message).filter_by(
                session_id=session_id,
                content=explanation,
                role="assistant"
            ).first()

            if not existing:
                db.session.add(Message(
                    id=str(uuid.uuid4()),
                    session_id=session_id,
                    device_id=device_id,
                    content=explanation,
                    role="assistant",
                    timestamp=now + 1
                ))

            session.updated_at = now + 1
            db.session.commit()

        return jsonify({
            "detected": label,
            "confidence": confidence,
            "explanation": explanation,
            "image_url": f"/uploads/temp/{device_id}/images/{os.path.basename(filepath)}"
        })

    except Exception as e:
        logger.error(f"Image analysis error: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/chat', methods=['POST'])
def chat():
    try:
        data = request.json
        message = data.get('message', '').strip()
        session_id = data.get('session_id', '')
        device_id = data.get('device_id', '')

        if not message:
            return jsonify({"error": "Message is required"}), 400
        if not session_id or not device_id:
            return jsonify({"error": "Session ID and Device ID are required"}), 400

        session = db.session.get(Session, session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404

        # Simpan topik jika belum ada
        if not session.topic:
            extracted_topic = extract_topic_from_question(message)
            session.topic = extracted_topic
            db.session.commit()

        # Panggil DeepSeek dengan riwayat + topik
        assistant_raw_response = get_deepseek_response(
            message,
            session_id=session_id,
            device_id=device_id
        )

        formatted_message = assistant_raw_response.replace('###', '').replace('*', '').strip()
        current_time = int(datetime.now().timestamp() * 1000)

        # Simpan pesan user dan assistant
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

        session.updated_at = current_time
        db.session.add_all([user_message, assistant_message])
        db.session.commit()

        return jsonify({
            "response": formatted_message,
            "clean_tts_message": formatted_message,
            "is_farming_related": True
        })

    except Exception as e:
        logger.error(f"Chat API error: {e}")
        return jsonify({"error": "An error occurred while processing your message"}), 500

@app.route('/uploads/audio/<filename>')
def serve_audio(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

@app.route('/uploads/images/<filename>')
def serve_image(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

def load_whisper_model():
    try:
        model = whisper.load_model("base")
        return model
    except Exception as e:
        logger.error(f"Failed to load Whisper model: {str(e)}")
        return None

app.whisper_model = load_whisper_model()

@app.route('/uploads/temp/<device_id>/audio/<filename>')
def serve_audio_file(device_id, filename):
    return send_from_directory(os.path.join(tempfile.gettempdir(), device_id, 'audio'), filename)

@app.route('/uploads/temp/<device_id>/images/<filename>')
def serve_image_file(device_id, filename):
    return send_from_directory(os.path.join(tempfile.gettempdir(), device_id, 'images'), filename)


def map_weather_condition(weather_main):
    """Map OpenWeather conditions to our frontend conditions"""
    weather_main = weather_main.lower()
    
    if any(x in weather_main for x in ['clear', 'sun']):
        return 'sunny'
    elif any(x in weather_main for x in ['cloud', 'fog', 'mist', 'haze']):
        return 'cloudy'
    elif any(x in weather_main for x in ['rain', 'drizzle', 'shower', 'thunder', 'storm']):
        return 'rainy'
    else:
        return 'cloudy'  # Default

def get_openweather_data(lat, lon):
    """Fetch weather data from OpenWeather API"""
    try:
        url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={OPENWEATHER_API_KEY}&units=metric&lang=id"
        response = requests.get(url)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"OpenWeather API error: {e}")
        return None

def get_farming_advice(weather_main):
    """Get farming advice based on weather condition"""
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

def get_mock_weather_data():
    """Return mock weather data for testing"""
    return {
        'temperature': 30.0,
        'condition': 'sunny',
        'description': 'Cerah',
        'location': 'Jakarta',
        'advice': 'Cocok untuk panen atau pengeringan hasil panen'
    }

def correct_user_question(raw_question):
    try:
        correction_payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": "Anda adalah asisten pintar yang tugasnya memperbaiki pertanyaan pengguna yang memiliki kesalahan ketik atau tidak jelas. Kembalikan versi pertanyaan yang lebih jelas, tanpa penjelasan tambahan."},
                {"role": "user", "content": raw_question}
            ],
            "temperature": 0.3,
            "max_tokens": 200
        }

        headers = {
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json"
        }

        response = requests.post(
            "https://api.deepseek.com/v1/chat/completions",
            headers=headers,
            json=correction_payload
        )

        if response.status_code == 200:
            result = response.json()
            corrected = result['choices'][0]['message']['content']
            return corrected.strip()
        else:
            logger.warning(f"DeepSeek correction failed, using original: {response.text}")
            return raw_question
    except Exception as e:
        logger.error(f"Correction error: {e}")
        return raw_question

def get_deepseek_response(prompt, session_id=None, device_id=None):
    try:
        session = db.session.get(Session, session_id) if session_id else None
        topic = session.topic.lower() if session and session.topic else None
        topic_instruction = f"\n\nTopik yang sedang dibahas adalah **{topic}**.\n" if topic else ""

        # Koreksi pertanyaan
        corrected_prompt = correct_user_question(prompt)

        # Ambil 2 pesan user terakhir yang sesuai topik
        history = []
        if session_id and device_id:
            messages = Message.query.filter_by(session_id=session_id, device_id=device_id)\
                                    .order_by(Message.timestamp.desc())\
                                    .all()
            for msg in messages:
                if msg.role == 'user' and (not topic or topic in msg.content.lower()):
                    history.append({"role": "user", "content": msg.content})
                    if len(history) >= 2:
                        break
        history = list(reversed(history))  # Urutkan lama ke baru
        history.append({"role": "user", "content": corrected_prompt})

        # Prompt lama + sisipan topik
        system_prompt = f"""Anda adalah Asisten Pertanian PeTaniku yang ahli di bidang:
- Pertanian dan perkebunan
- Cuaca dan iklim untuk pertanian
- Pengelolaan tanaman dan tanah
- Teknologi pertanian
{topic_instruction}
Bantu pengguna dengan:
1. Berikan jawaban singkat dan jelas untuk pertanyaan pertanian
2. Jika pertanyaan di luar topik, jawab dengan sopan:
   "Maaf, saya hanya dapat membantu tentang pertanian. Ada yang bisa saya bantu terkait tanaman, cuaca pertanian, atau hal terkait?"

Gaya respons:
- Gunakan bahasa sederhana dan praktis
- Format jelas dengan paragraf terpisah
- Hindari jargon teknis berlebihan"""

        payload = {
            "model": "deepseek-chat",
            "messages": [{"role": "system", "content": system_prompt}] + history,
            "temperature": 0.5,
            "max_tokens": 1000
        }

        headers = {
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json"
        }

        response = requests.post("https://api.deepseek.com/v1/chat/completions", headers=headers, json=payload)

        if response.status_code == 200:
            result = response.json()
            return result['choices'][0]['message']['content']
        else:
            logger.error(f"DeepSeek API error: {response.text}")
            return "Maaf, saya tidak bisa memberikan jawaban saat ini."

    except Exception as e:
        logger.error(f"Error getting DeepSeek response: {e}")
        return "Maaf, terjadi kesalahan dalam memproses permintaan Anda."

def extract_topic_from_question(question):
    try:
        response = get_deepseek_response(
            f"Apa topik utama dari pertanyaan ini? '{question}'. Beri jawaban singkat, maksimal 3 kata."
        )
        return response.strip()
    except Exception as e:
        logger.error(f"Gagal ekstrak topik: {e}")
        return None

if __name__ == '__main__':
    app.run()