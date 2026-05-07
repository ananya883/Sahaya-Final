FROM python:3.9-slim

WORKDIR /app

# Install system dependencies if required and clean up to keep image small
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements_production.txt .

# Install dependencies from requirements
RUN pip install --no-cache-dir -r requirements_production.txt

# Install PyTorch and facenet-pytorch missing from requirements but needed by app.py
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir facenet-pytorch

COPY . .

EXPOSE 5002

CMD ["python", "app.py"]
