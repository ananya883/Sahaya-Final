from flask import Flask, request, jsonify
from facenet_pytorch import MTCNN, InceptionResnetV1
from PIL import Image
import torch
import numpy as np
import os
import requests
from numpy.linalg import norm
from pathlib import Path
from dotenv import load_dotenv
try:
    from predict_rf_alert import RFDisasterAlertSystem
except ImportError:
    RFDisasterAlertSystem = None

app = Flask(__name__)
base_dir = Path(__file__).resolve().parent.parent
env_path = base_dir / "backend" / ".env"

OPENWEATHER_API_KEY = None
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
    OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")

try:
    if RFDisasterAlertSystem is not None:
        alert_system = RFDisasterAlertSystem()
    else:
        alert_system = None
except Exception as e:
    print(f"Failed to load RF Model: {e}")
    alert_system = None

def get_current_weather(lat, lon, name):
    if not OPENWEATHER_API_KEY:
        return None
    url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={OPENWEATHER_API_KEY}&units=metric"
    try:
        response = requests.get(url, timeout=5)
        data = response.json()
        if response.status_code == 200 and "main" in data:
            return {
                "location": name,
                "temperature": data["main"]["temp"],
                "humidity": data["main"]["humidity"],
                "windspeed": data["wind"]["speed"],
                "rainfall": data.get("rain", {}).get("1h", 0)
            }
    except Exception:
        pass
    return None

# -----------------------------
# Load Face Detection & FaceNet
# -----------------------------
# MTCNN for face detection + alignment
mtcnn = MTCNN(
    image_size=160,
    margin=20,
    select_largest=True,
    post_process=True
)

# FaceNet model (128-D embedding)
facenet = InceptionResnetV1(
    pretrained='vggface2'
).eval()

# -----------------------------
# Utility: Extract FaceNet Embedding
# -----------------------------
def extract_facenet_embedding(image_path):
    """
    Takes image path
    Returns 128-D embedding or None
    """
    try:
        img = Image.open(image_path).convert('RGB')
    except Exception:
        return None

    face = mtcnn(img)

    if face is None:
        return None

    with torch.no_grad():
        embedding = facenet(face.unsqueeze(0))

    return embedding[0].numpy()


# -----------------------------
# Utility: Cosine Similarity
# -----------------------------
def cosine_similarity(vec1, vec2):
    return np.dot(vec1, vec2) / (norm(vec1) * norm(vec2))


# -----------------------------
# API: Extract Embedding
# -----------------------------
@app.route('/extract', methods=['POST'])
def extract():
    # Check for file upl  oad (multipart/form-data)
    if 'image' in request.files:
        print("📸 [AI] Received image file upload", flush=True)
        image_file = request.files['image']
        temp_path = "temp_image.jpg"
        image_file.save(temp_path)
        
        try:
            print(f"🔄 [AI] Processing image from {temp_path}...", flush=True)
            embedding = extract_facenet_embedding(temp_path)
            print("✅ [AI] Embedding extraction complete (file)", flush=True)
        except Exception as e:
             print(f"❌ [AI] Error processing file: {e}", flush=True)
             embedding = None
        finally:
             if os.path.exists(temp_path):
                 os.remove(temp_path)
                 
    # Check for JSON body (application/json)
    elif request.is_json and 'imagePath' in request.get_json():
        data = request.get_json()
        image_path = data['imagePath']
        print(f"📸 [AI] Received image path: {image_path}", flush=True)
        
        if not os.path.exists(image_path):
             print(f"❌ [AI] File not found: {image_path}", flush=True)
             return jsonify({"error": f"File not found at {image_path}"}), 400
             
        embedding = extract_facenet_embedding(image_path)
        print("✅ [AI] Embedding extraction complete (path)", flush=True)
        
    else:
        print("⚠️ [AI] No image provided in request", flush=True)
        return jsonify({"error": "No image file or imagePath provided"}), 400

    if embedding is None:
        print("⚠️ [AI] No face detected or extraction failed", flush=True)
        return jsonify({"error": "No face detected"}), 400

    return jsonify({
        "embedding": embedding.tolist()
    })


# -----------------------------
# API: Match Two Faces
# -----------------------------
@app.route('/match', methods=['POST'])
def match():
    print("🤝 [AI] Match request received", flush=True)
    data = request.get_json()

    if not data or 'embedding1' not in data or 'embedding2' not in data:
        print("❌ [AI] Invalid match input (missing embeddings)", flush=True)
        return jsonify({"error": "Invalid input"}), 400

    try:
        emb1 = np.array(data['embedding1'])
        emb2 = np.array(data['embedding2'])

        similarity = cosine_similarity(emb1, emb2)
        print(f"🔍 [AI] Similarity calculated: {similarity}", flush=True)

        # Thresholds (can be tuned)
        if similarity >= 0.85:
            result = "Strong Match"
        elif similarity >= 0.75:
            result = "Possible Match"
        else:
            result = "No Match"
        
        return jsonify({
            "similarity": float(similarity),
            "result": result
        })
    except Exception as e:
        print(f"❌ [AI] Match error: {e}", flush=True)
        return jsonify({"error": str(e)}), 500


# -----------------------------
# API: Predict Disaster Alerts
# -----------------------------
@app.route('/predict-alerts', methods=['POST'])
def predict_alerts():
    if not alert_system or alert_system.model is None:
        return jsonify({"error": "ML Model not loaded"}), 500
    
    data = request.get_json()
    if not data or 'locations' not in data:
        return jsonify({"error": "No locations provided"}), 400
        
    requested_locations = data['locations']
    
    # Pre-defined known locations library
    KNOWN_LOCATIONS = {
        "Vannappuram": (9.90, 76.80),
        "Adimali": (10.02, 76.97),
        "Cheruthoni": (9.85, 76.98),
        "Kokkayar": (9.57, 76.85),
        "Sulthan Bathery": (11.67, 76.27),
        "Meppadi": (11.55, 76.13),
        "Kalpetta": (11.61, 76.08),
        "Munnar": (10.09, 77.06),
        "Vythiri": (11.55, 76.04),
        "Mananthavady": (11.80, 76.00)
    }
    
    predictions = []
    
    for loc in requested_locations:
        if loc in KNOWN_LOCATIONS:
            lat, lon = KNOWN_LOCATIONS[loc]
            weather_data = get_current_weather(lat, lon, loc)
            
            if weather_data:
                result = alert_system.predict_alert(
                    rainfall=weather_data['rainfall'],
                    humidity=weather_data['humidity'],
                    windspeed=weather_data['windspeed'],
                    temperature=weather_data['temperature']
                )
                if result.get("status") != "FAILED":
                    predictions.append({
                        "location": loc,
                        "data": weather_data,
                        "prediction": result
                    })
                    
    return jsonify({"alerts": predictions})

# -----------------------------
# Run Server
# -----------------------------
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002, debug=True)
