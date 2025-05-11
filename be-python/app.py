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
import base64
import json
import io
from PIL import Image

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
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
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
    device_id = db.Column(db.String(255), nullable=False, index=True)
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
    role = db.Column(db.String(20), nullable=False)  # 'user' or 'assistant'
    timestamp = db.Column(db.BigInteger, nullable=False)
    
    # File paths - nullable karena tidak semua pesan punya file
    audio_path = db.Column(db.String(512), nullable=True)
    image_path = db.Column(db.String(512), nullable=True)
    
    # Remove these fields that are causing the error
    # audio_duration = db.Column(db.Integer, nullable=True)
    # audio_format = db.Column(db.String(10), nullable=True)

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
    logger.error(f"Internal server error: {error}")
    return jsonify({"error": "Internal server error", "details": str(error)}), 500

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
        
    # Verify the session belongs to the device
    session = Session.query.filter_by(id=session_id, device_id=device_id).first()
    if not session:
        return jsonify({"error": "Session not found"}), 404
    
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
        # Create upload directory if it doesn't exist
        upload_folder = get_upload_folder(device_id, 'audio')
        os.makedirs(upload_folder, exist_ok=True)
        
        # Generate unique filename
        filename = f"audio_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.wav"
        filepath = os.path.join(upload_folder, filename)
        
        # Save the file
        audio_file.save(filepath)
        
        # Verify file was saved
        if not os.path.exists(filepath):
            raise Exception("File failed to save")

        return jsonify({
            "status": "success",
            "file_path": f"/uploads/{device_id}/audio/{filename}",
            "file_url": f"/uploads/{device_id}/audio/{filename}"
        })

    except Exception as e:
        logger.error(f"Audio upload error: {str(e)}")
        return jsonify({"error": "Audio upload failed", "details": str(e)}), 500

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
        
        # Process image before saving
        img = Image.open(image_file)
        
        # Convert to RGB if it has an alpha channel (RGBA)
        if img.mode == 'RGBA':
            img = img.convert('RGB')
        
        # Resize if larger than 1024x1024
        if img.width > 1024 or img.height > 1024:
            img.thumbnail((1024, 1024))
        
        # Save as JPEG
        img.save(filepath, format='JPEG', quality=85)

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

# Update the vision endpoint to handle images more reliably
@app.route('/api/vision', methods=['POST'])
def analyze_image():
    try:
        logger.info("Vision API called")
        
        # Get request data
        device_id = None
        session_id = None
        prompt = "Analisis gambar tanaman ini dan berikan informasi tentang kondisinya."
        img_base64 = None
        filename = None
        
        if request.is_json:
            # Handle JSON request with base64 image
            data = request.json
            device_id = data.get('device_id')
            session_id = data.get('session_id')
            prompt = data.get('prompt', prompt)
            img_base64 = data.get('image_base64')
            
            logger.info(f"JSON request received with device_id: {device_id}, session_id: {session_id}")
            
            if not img_base64:
                return jsonify({"error": "No image_base64 provided"}), 400
                
            # Process base64 image
            try:
                # Save base64 image to file
                upload_folder = get_upload_folder(device_id, 'images')
                filename = f"img_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.jpg"
                filepath = os.path.join(upload_folder, filename)
                
                # Decode and save base64 image
                try:
                    # Remove data URL prefix if present
                    if ',' in img_base64:
                        img_base64 = img_base64.split(',')[1]
                        
                    img_data = base64.b64decode(img_base64)
                    
                    # Process image with PIL
                    try:
                        img = Image.open(io.BytesIO(img_data))
                        
                        # Convert to RGB if needed
                        if img.mode != 'RGB':
                            img = img.convert('RGB')
                        
                        # Resize if larger than 1024x1024
                        if img.width > 1024 or img.height > 1024:
                            img.thumbnail((1024, 1024))
                        
                        # Save as JPEG
                        img.save(filepath, format='JPEG', quality=85)
                        
                        # Get the processed image data for API
                        buffer = io.BytesIO()
                        img.save(buffer, format="JPEG")
                        img_data = buffer.getvalue()
                        img_base64 = base64.b64encode(img_data).decode('utf-8')
                    except Exception as e:
                        logger.error(f"Error processing image with PIL: {e}")
                        # If PIL processing fails, save the original data
                        with open(filepath, 'wb') as f:
                            f.write(img_data)
                            
                    logger.info(f"Image saved to {filepath}")
                except Exception as e:
                    logger.error(f"Error decoding base64 image: {e}")
                    return jsonify({"error": "Invalid base64 image"}), 400
            except Exception as e:
                logger.error(f"Error processing base64 image: {e}")
                return jsonify({"error": "Failed to process base64 image"}), 400
        else:
            # Handle multipart form data
            device_id = request.form.get('device_id')
            session_id = request.form.get('session_id')
            prompt = request.form.get('prompt', prompt)
            
            logger.info(f"Form request received with device_id: {device_id}, session_id: {session_id}")
            
            if 'image' not in request.files:
                return jsonify({"error": "No image file provided"}), 400
                
            image_file = request.files['image']
            if image_file.filename == '':
                return jsonify({"error": "Empty filename"}), 400
                
            # Process and save the image file
            upload_folder = get_upload_folder(device_id, 'images')
            filename = secure_filename(f"img_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.jpg")
            filepath = os.path.join(upload_folder, filename)
            
            # Process image with PIL
            try:
                img = Image.open(image_file)
                
                # Convert to RGB if needed
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                
                # Resize if larger than 1024x1024
                if img.width > 1024 or img.height > 1024:
                    img.thumbnail((1024, 1024))
                
                # Save as JPEG
                img.save(filepath, format='JPEG', quality=85)
                
                # Convert image to base64 for DeepSeek API
                with open(filepath, "rb") as img_file:
                    img_data = img_file.read()
                    img_base64 = base64.b64encode(img_data).decode('utf-8')
            except Exception as e:
                logger.error(f"Error processing image with PIL: {e}")
                # If PIL processing fails, save the original file
                image_file.seek(0)
                image_file.save(filepath)
                
                # Convert image to base64 for DeepSeek API
                with open(filepath, "rb") as img_file:
                    img_data = img_file.read()
                    img_base64 = base64.b64encode(img_data).decode('utf-8')

        if not device_id:
            return jsonify({"error": "Device ID is required"}), 400
        if not session_id:
            return jsonify({"error": "Session ID is required"}), 400
        if not filename:
            return jsonify({"error": "Failed to process image"}), 500

        # Send to DeepSeek API for analysis
        logger.info("Preparing DeepSeek API request")
        headers = {
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json"
        }

        # Fix the payload format to match DeepSeek API requirements
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
                        {"type": "image_url", "image_url": f"data:image/jpeg;base64,{img_base64}"}
                    ]
                }
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        }

        try:
            logger.info("Sending request to DeepSeek API")
            response = requests.post(
                "https://api.deepseek.com/v1/chat/completions",
                headers=headers,
                json=payload,
                timeout=60  # Increased timeout
            )

            logger.info(f"DeepSeek API response status: {response.status_code}")
            
            if response.status_code != 200:
                logger.error(f"DeepSeek API error: {response.text}")
                # Return a fallback response instead of an error
                return jsonify({
                    "status": "success",
                    "analysis": "Maaf, saya tidak dapat menganalisis gambar saat ini. Silakan coba lagi nanti.",
                    "image_path": f"/uploads/{device_id}/images/{filename}"
                })

            result = response.json()
            logger.info("Successfully received DeepSeek API response")
            analysis = result['choices'][0]['message']['content']
        except Exception as e:
            logger.error(f"Error calling DeepSeek API: {e}")
            # Return a fallback response
            return jsonify({
                "status": "success",
                "analysis": "Maaf, saya tidak dapat menganalisis gambar saat ini. Silakan coba lagi nanti.",
                "image_path": f"/uploads/{device_id}/images/{filename}"
            })

        # Try to save messages to database
        try:
            # Save user message with image
            user_message = Message(
                id=str(uuid.uuid4()),
                session_id=session_id,
                device_id=device_id,
                content=prompt,
                role='user',
                timestamp=int(datetime.now().timestamp() * 1000),
                image_path=f"/uploads/{device_id}/images/{filename}"
            )
            
            # Save assistant response
            assistant_message = Message(
                id=str(uuid.uuid4()),
                session_id=session_id,
                device_id=device_id,
                content=analysis,
                role='assistant',
                timestamp=int(datetime.now().timestamp() * 1000) + 1
            )
            
            session = Session.query.filter_by(id=session_id).first()
            if session:
                session.updated_at = int(datetime.now().timestamp() * 1000)
                db.session.add_all([user_message, assistant_message])
                db.session.commit()
                logger.info("Messages saved to database")
        except Exception as e:
            logger.error(f"Error saving messages to database: {e}")
            # Continue even if database save fails

        return jsonify({
            "status": "success",
            "analysis": analysis,
            "image_path": f"/uploads/{device_id}/images/{filename}"
        })

    except Exception as e:
        logger.error(f"Image analysis error: {str(e)}")
        return jsonify({
            "status": "success",
            "analysis": "Maaf, saya tidak dapat menganalisis gambar saat ini. Silakan coba lagi nanti.",
            "image_path": None
        })

@app.route('/api/transcribe', methods=['POST'])
def transcribe_audio():
    try:
        logger.info("Transcribe endpoint called")

        if 'audio' not in request.files:
            logger.error("No audio file provided")
            return jsonify({"error": "No audio file provided"}), 400

        device_id = request.form.get('device_id')
        session_id = request.form.get('session_id')

        if not device_id:
            logger.warning("Device ID is required but not provided")
            return jsonify({"error": "Device ID is required"}), 400
        
        if not session_id:
            logger.warning("Session ID is required but not provided")
            return jsonify({"error": "Session ID is required"}), 400

        audio_file = request.files['audio']
        if audio_file.filename == '':
            logger.error("Empty filename")
            return jsonify({"error": "Empty filename"}), 400

        # Save the audio file first
        upload_folder = get_upload_folder(device_id, 'audio')
        filename = f"audio_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.wav"
        filepath = os.path.join(upload_folder, filename)
        
        logger.info(f"Saving audio file to: {filepath}")
        audio_file.save(filepath)

        # Verify file was saved
        if not os.path.exists(filepath):
            raise Exception("Audio file failed to save")

        # Transcribe with Whisper
        if WHISPER_MODEL is None:
            logger.error("Whisper model not available")
            return jsonify({
                "error": "Whisper model not available",
                "transcription": "Maaf, layanan pengenalan suara sedang tidak tersedia.",
                "ai_response": "Silakan coba lagi nanti atau ketik pesan Anda.",
                "audio_path": f"/uploads/{device_id}/audio/{filename}"
            }), 200

        logger.info("Transcribing with Whisper model")
        try:
            result = WHISPER_MODEL.transcribe(filepath)
            transcription = result["text"].strip()
            logger.info(f"Transcription result: '{transcription}'")
            
            if not transcription:
                transcription = "Pesan suara kosong"
                logger.warning("Empty transcription result, using default message")
        except Exception as e:
            logger.error(f"Error during transcription: {e}")
            transcription = "Maaf, saya tidak dapat mengenali suara Anda saat ini."

        # Send to DeepSeek API for response
        try:
            logger.info("Sending to DeepSeek API")
            headers = {
                "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
                "Content-Type": "application/json"
            }
            
            payload = {
                "model": "deepseek-chat",
                "messages": [
                    {
                        "role": "system", 
                        "content": """Anda adalah Asisten Pertanian PeTaniku yang ahli di bidang:
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
- Hindari jargon teknis berlebihan"""
                    },
                    {"role": "user", "content": transcription}
                ],
                "temperature": 0.7,
                "max_tokens": 1000
            }
            
            logger.info("Sending request to DeepSeek API")
            response = requests.post(
                "https://api.deepseek.com/v1/chat/completions",
                headers=headers,
                json=payload,
                timeout=30
            )
            
            logger.info(f"DeepSeek API response status: {response.status_code}")
            result = response.json()
            logger.info(f"DeepSeek API response: {result}")
            
            if response.status_code == 200:
                ai_response = result['choices'][0]['message']['content']
                
                # Save messages to database
                try:
                    current_time = int(datetime.now().timestamp() * 1000)
                    
                    # Save user message with audio
                    user_message = Message(
                        id=str(uuid.uuid4()),
                        session_id=session_id,
                        device_id=device_id,
                        content=transcription,
                        role='user',
                        timestamp=current_time,
                        audio_path=f"/uploads/{device_id}/audio/{filename}"
                    )
                    
                    # Save assistant response
                    assistant_message = Message(
                        id=str(uuid.uuid4()),
                        session_id=session_id,
                        device_id=device_id,
                        content=ai_response,
                        role='assistant',
                        timestamp=current_time + 1
                    )
                    
                    session = Session.query.filter_by(id=session_id).first()
                    if session:
                        session.updated_at = current_time
                        db.session.add_all([user_message, assistant_message])
                        db.session.commit()
                        logger.info("Messages saved to database")
                except Exception as e:
                    logger.error(f"Error saving messages to database: {e}")
                    # Continue even if database save fails

                return jsonify({
                    "status": "success",
                    "transcription": transcription,
                    "ai_response": ai_response,
                    "audio_path": f"/uploads/{device_id}/audio/{filename}"
                })
            else:
                logger.error(f"DeepSeek API error: {result}")
                return jsonify({
                    "error": "Failed to get AI response", 
                    "details": result,
                    "transcription": transcription,
                    "ai_response": "Maaf, saya tidak dapat memproses permintaan Anda saat ini. Silakan coba lagi nanti.",
                    "audio_path": f"/uploads/{device_id}/audio/{filename}"
                }), 200
        except Exception as e:
            logger.error(f"Error calling DeepSeek API: {e}")
            return jsonify({
                "error": "Failed to get AI response",
                "transcription": transcription,
                "ai_response": "Maaf, saya tidak dapat memproses permintaan Anda saat ini. Silakan coba lagi nanti.",
                "audio_path": f"/uploads/{device_id}/audio/{filename}"
            }), 200
            
    except Exception as e:
        logger.error(f"Transcription error: {str(e)}")
        return jsonify({
            "error": "Audio transcription failed", 
            "details": str(e),
            "transcription": "Maaf, saya tidak dapat mengenali suara Anda saat ini.",
            "ai_response": "Silakan coba lagi nanti atau ketik pesan Anda.",
            "audio_path": None
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
        
        # Verify session exists and belongs to device
        session = None
        if session_id:
            session = Session.query.filter_by(id=session_id, device_id=device_id).first()
            if not session:
                return jsonify({"error": "Session not found"}), 404
        
        # Create new session if none exists
        if not session:
            session = Session(
                id=str(uuid.uuid4()),
                device_id=device_id,
                name=message[:30] if message else "Percakapan Baru",
                created_at=int(datetime.now().timestamp() * 1000),
                updated_at=int(datetime.now().timestamp() * 1000)
            )
            db.session.add(session)
            db.session.commit()
            session_id = session.id

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
            try:
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
                
                session.updated_at = current_time
                db.session.add_all([user_message, assistant_message])
                db.session.commit()
            except Exception as e:
                logger.error(f"Error saving chat messages to database: {e}")
                # Continue even if database save fails
            
            return jsonify({
                "response": formatted_message,
                "session_id": session_id
            })
        else:
            logger.error(f"DeepSeek API error: {result}")
            return jsonify({
                "response": "Maaf, saya tidak dapat memproses permintaan Anda saat ini. Silakan coba lagi nanti.",
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
