from datetime import datetime
import os
import uuid
from venv import logger
from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
import python2pseudocode # <-- Library diimpor
import requests

app = Flask(__name__)

# --- Konfigurasi dan model database (tidak ada perubahan) ---
app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(os.path.dirname(__file__), 'chatbot.db')}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")

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

# --- Endpoint /api/chat (tidak ada perubahan) ---
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

        if not session.topic:
            extracted_topic = extract_topic_from_question(message)
            session.topic = extracted_topic
            db.session.commit()

        assistant_raw_response = get_deepseek_response(
            message,
            session_id=session_id,
            device_id=device_id
        )

        formatted_message = assistant_raw_response.replace('###', '').replace('*', '').strip()
        current_time = int(datetime.now().timestamp() * 1000)

        user_message = Message(
            id=str(uuid.uuid4()), session_id=session_id, device_id=device_id,
            content=message, role='user', timestamp=current_time
        )
        assistant_message = Message(
            id=str(uuid.uuid4()), session_id=session_id, device_id=device_id,
            content=formatted_message, role='assistant', timestamp=current_time + 1
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

# --- Fungsi-fungsi lain (tidak ada perubahan) ---
def correct_user_question(raw_question):
    # ... (logika fungsi tidak diubah)
    try:
        correction_payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": "Anda adalah asisten pintar yang tugasnya memperbaiki pertanyaan pengguna yang memiliki kesalahan ketik atau tidak jelas. Kembalikan versi pertanyaan yang lebih jelas, tanpa penjelasan tambahan."},
                {"role": "user", "content": raw_question}
            ],
            "temperature": 0.3, "max_tokens": 200
        }
        headers = {"Authorization": f"Bearer {DEEPSEEK_API_KEY}", "Content-Type": "application/json"}
        response = requests.post("https://api.deepseek.com/v1/chat/completions", headers=headers, json=correction_payload)
        if response.status_code == 200:
            result = response.json()
            return result['choices'][0]['message']['content'].strip()
        else:
            logger.warning(f"DeepSeek correction failed, using original: {response.text}")
            return raw_question
    except Exception as e:
        logger.error(f"Correction error: {e}")
        return raw_question

def get_deepseek_response(prompt, session_id=None, device_id=None):
    # ... (logika fungsi tidak diubah)
    try:
        session = db.session.get(Session, session_id) if session_id else None
        topic = session.topic.lower() if session and session.topic else None
        topic_instruction = f"\n\nTopik yang sedang dibahas adalah **{topic}**.\n" if topic else ""
        corrected_prompt = correct_user_question(prompt)
        history = []
        if session_id and device_id:
            messages = Message.query.filter_by(session_id=session_id, device_id=device_id).order_by(Message.timestamp.desc()).all()
            for msg in messages:
                if msg.role == 'user' and (not topic or topic in msg.content.lower()):
                    history.append({"role": "user", "content": msg.content})
                    if len(history) >= 2: break
        history = list(reversed(history))
        history.append({"role": "user", "content": corrected_prompt})
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
        payload = {"model": "deepseek-chat", "messages": [{"role": "system", "content": system_prompt}] + history, "temperature": 0.5, "max_tokens": 1000}
        headers = {"Authorization": f"Bearer {DEEPSEEK_API_KEY}", "Content-Type": "application/json"}
        response = requests.post("https://api.deepseek.com/v1/chat/completions", headers=headers, json=payload)
        if response.status_code == 200:
            return response.json()['choices'][0]['message']['content']
        else:
            logger.error(f"DeepSeek API error: {response.text}")
            return "Maaf, saya tidak bisa memberikan jawaban saat ini."
    except Exception as e:
        logger.error(f"Error getting DeepSeek response: {e}")
        return "Maaf, terjadi kesalahan dalam memproses permintaan Anda."

def extract_topic_from_question(question):
    # ... (logika fungsi tidak diubah)
    try:
        response = get_deepseek_response(
            f"Apa topik utama dari pertanyaan ini? '{question}'. Beri jawaban singkat, maksimal 3 kata."
        )
        return response.strip()
    except Exception as e:
        logger.error(f"Gagal ekstrak topik: {e}")
        return None

# ==========================================================
#  Endpoint Baru untuk Membuat Pseudocode Secara Dinamis
# ==========================================================
@app.route('/api/pseudocode/<function_name>', methods=['GET'])
def get_pseudocode(function_name):
    """
    Endpoint ini akan mengonversi fungsi Python yang ada menjadi pseudocode.
    """
    # Membuat pemetaan dari nama string ke objek fungsi yang sebenarnya.
    # Ini lebih aman daripada menggunakan eval().
    function_map = {
        'chat': chat,
        'get_deepseek_response': get_deepseek_response,
        'correct_user_question': correct_user_question,
        'extract_topic_from_question': extract_topic_from_question
    }

    # Ambil objek fungsi dari map berdasarkan nama yang diminta
    target_function = function_map.get(function_name)

    if not target_function:
        return jsonify({"error": f"Function '{function_name}' not found or not allowed."}), 404

    try:
        # Konversi fungsi menjadi pseudocode menggunakan library
        pseudo = python2pseudocode.convert(target_function)
        
        # Kembalikan hasilnya dalam format JSON, dibungkus <pre> untuk mempertahankan format
        return jsonify({
            "function_name": function_name,
            "pseudocode": pseudo
        })
    except Exception as e:
        logger.error(f"Failed to generate pseudocode for {function_name}: {e}")
        return jsonify({"error": f"Could not generate pseudocode for function '{function_name}'."}), 500
if __name__ == '__main__':
    app.run()

# import os.path
# import re

# '''
# INSTRUCTIONS
# 1. Create a file with the following code
# 2. Put the file you want to convert into the same folder as it, and rename it to "app.py"
# 3. Add a "#F" comment to any lines in the code which have a function call that doesn't assign anything (so no =),
# as the program cannot handle these convincingly
# 4. Run the converter file
# '''

# python_file = 'app.py'

# basic_conversion_rules = {"for": "FOR", "=": "TO", "if": "IF", "==": "EQUALS", "while": "WHILE", "until": "UNTIL",
#                           "import": "IMPORT", "class": "DEFINE CLASS", "def": "DEFINE FUNCTION", "else:": "ELSE:",
#                           "elif": "ELSEIF", "except:": "EXCEPT:", "try:": "TRY:", "pass": "PASS", "in": "IN"}
# prefix_conversion_rules = {"=": "SET ", "#F": "CALL "}
# advanced_conversion_rules = {"print": "OUTPUT", "return": "RETURN", "input": "INPUT"}


# def l2pseudo(to_pseudo):
#     for line in to_pseudo:
#         line_index = to_pseudo.index(line)
#         line = str(line)
#         line = re.split(r'(\s+)', line)
#         for key, value in prefix_conversion_rules.items():
#             if key in line:
#                 if not str(line[0]) == '':
#                     line[0] = value + line[0]
#                 else:
#                     line[2] = value + line[2]
#         for key, value in basic_conversion_rules.items():
#             for word in line:
#                 if key == str(word):
#                     line[line.index(word)] = value
#         for key, value in advanced_conversion_rules.items():
#             for word in line:
#                 line[line.index(word)] = word.replace(key, value)
#         for key, value in prefix_conversion_rules.items():
#             for word in line:
#                 if word == key:
#                     del line[line.index(word)]
#         to_pseudo[line_index] = "".join(line)
#     return to_pseudo


# def p2file(to_file):
#     app = os.path.splitext(os.path.basename(python_file))[0]
#     # Menambahkan encoding='utf-8' juga saat menulis untuk konsistensi
#     with open(app + '_pseudo.txt', 'w', encoding='utf-8') as writer:
#         writer.write("\n".join(to_file))


# def main():
#     # PERBAIKAN: Menambahkan encoding='utf-8' di sini
#     with open(python_file, 'r+', encoding='utf-8') as app_reader:
#         file_lines = app_reader.readlines()
#         work_file = l2pseudo(file_lines)
#         p2file(work_file)


# if __name__ == '__main__':
#     main()