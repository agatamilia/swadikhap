# Gunakan base image yang mendukung Whisper (ffmpeg + pytorch)
FROM python:3.10-slim

# Install dependencies untuk Whisper dan audio/image processing
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsm6 \
    libxext6 \
    git \
    && rm -rf /var/lib/apt/lists/*

# Buat working directory
WORKDIR /app

# Copy semua file ke container
COPY . .

# Install dependencies Python
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

# Expose port (bisa diganti kalau tidak pakai 5000)
EXPOSE 5000

# Jalankan aplikasi Flask
CMD ["python", "app.py"]
