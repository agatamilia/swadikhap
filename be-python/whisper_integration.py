# Add to your Flask app.py file:

import whisper
import tempfile
import os
from datetime import datetime
import uuid
from werkzeug.utils import secure_filename

# Initialize Whisper model (do this at app startup)
WHISPER_MODEL = whisper.load_model("base")

# Create upload folder for audio
UPLOAD_AUDIO_FOLDER = 'uploads/audio'
os.makedirs(UPLOAD_AUDIO_FOLDER, exist_ok=True)

@app.route('/api/transcribe', methods=['POST'])
def transcribe_audio():
    if 'audio' not in request.files:
        return jsonify({"error": "No audio file provided"}), 400

    audio_file = request.files['audio']
    if audio_file.filename == '':
        return jsonify({"error": "Empty filename"}), 400
        
    try:
        # Save file
        filename = secure_filename(f"audio_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.wav")
        filepath = os.path.join(UPLOAD_AUDIO_FOLDER, filename)
        audio_file.save(filepath)
        
        # Check file size
        file_size = os.path.getsize(filepath)
        if file_size < 100:  # Very small files are likely corrupted
            return jsonify({"error": "Audio file is too small or corrupted"}), 400
            
        # Process with Whisper
        logger.info(f"Processing audio file: {filepath}")
        result = WHISPER_MODEL.transcribe(
            filepath, 
            language="id",  # Indonesian language
            fp16=False      # Use CPU-compatible mode
        )
        
        transcription = result["text"]
        logger.info(f"Transcription: {transcription}")
        
        # Process with DeepSeek
        session_id = request.form.get('session_id')
        ai_response = "Maaf, saya tidak dapat memproses pesan suara Anda saat ini."
        
        if transcription and session_id:
            try:
                # Call DeepSeek API
                headers = {
                    "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
                    "Content-Type": "application/json"
                }
                
                payload = {
                    "model": "deepseek-chat",
                    "messages": [
                        {"role": "system", "content": "Anda adalah asisten pertanian PeTaniku. Berikan informasi yang akurat dan bermanfaat tentang pertanian."},
                        {"role": "user", "content": transcription}
                    ],
                    "temperature": 0.7,
                    "max_tokens": 1000
                }
                
                response = requests.post(
                    "https://api.deepseek.com/v1/chat/completions",
                    headers=headers,
                    json=payload
                )
                
                if response.status_code == 200:
                    result = response.json()
                    ai_response = result['choices'][0]['message']['content']
                    
                    # Save in database
                    session = db.session.get(Session, session_id)
                    if session:
                        current_time = int(datetime.now().timestamp() * 1000)
                        
                        # Save audio message
                        audio_message = Message(
                            id=str(uuid.uuid4()),
                            session_id=session_id,
                            content=transcription,
                            role='user',
                            timestamp=current_time,
                            audio_path=f"/uploads/audio/{filename}"
                        )
                        
                        # Save AI response
                        response_message = Message(
                            id=str(uuid.uuid4()),
                            session_id=session_id,
                            content=ai_response,
                            role='assistant',
                            timestamp=current_time + 1
                        )
                        
                        # Update session timestamp
                        session.updated_at = current_time
                        
                        db.session.add_all([audio_message, response_message])
                        db.session.commit()
                else:
                    logger.error(f"DeepSeek API error: {response.text}")
            except Exception as e:
                logger.error(f"Error processing transcription with DeepSeek: {e}")
        
        return jsonify({
            "transcription": transcription,
            "ai_response": ai_response,
            "audio_path": f"/uploads/audio/{filename}"
        })
        
    except Exception as e:
        logger.error(f"Transcription error: {str(e)}")
        return jsonify({"error": f"Transcription failed: {str(e)}"}), 500

# Serve uploaded audio
@app.route('/uploads/audio/<filename>')
def serve_audio(filename):
    return send_from_directory(UPLOAD_AUDIO_FOLDER, filename)

