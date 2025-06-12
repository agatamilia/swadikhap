import os
import sys
import logging
import torch

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def setup_whisper_path():
    """Add whisper to Python path"""
    whisper_dir = os.path.join(os.path.dirname(__file__), 'whisper')
    if os.path.exists(whisper_dir) and whisper_dir not in sys.path:
        sys.path.insert(0, whisper_dir)
        logger.info(f"Added {whisper_dir} to Python path")
        return True
    return False

def load_model(model_name="base"):
    try:
        logger.info(f"Mencoba memuat model Whisper: {model_name}")
        import whisper
        model = whisper.load_model(model_name)
        logger.info("Model Whisper berhasil dimuat")
        return model
    except Exception as e:
        logger.error(f"Gagal memuat model Whisper: {str(e)}")
        return None

def transcribe(model, audio_path, language="id"):
    try:
        if not os.path.exists(audio_path):
            return {"error": "Audio file does not exist"}
        if os.path.getsize(audio_path) < 1024:
            return {"error": "Audio file too small"}

        result = model.transcribe(
            audio_path,
            language=language,
            temperature=0.2
        )
        return result
    except Exception as e:
        logger.error(f"Transcription failed: {str(e)}")
        return {"error": str(e)}
