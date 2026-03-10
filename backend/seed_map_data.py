import urllib.request
import urllib.parse
import json
import random
import time

BASE_URL = "http://114.55.148.245:8000"

# Mock data
# Center around Beijing (39.9042, 116.4074) for testing
CENTER_LAT = 39.9042
CENTER_LNG = 116.4074

def get_token(username, password):
    url = f"{BASE_URL}/token"
    data = urllib.parse.urlencode({"username": username, "password": password}).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header('Content-Type', 'application/x-www-form-urlencoded')
    
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())["access_token"]
    except Exception as e:
        print(f"Login failed: {e}")
        return None

def create_feedback(token, lat, lng, type_):
    url = f"{BASE_URL}/messages/feedback"
    data = json.dumps({
        "type": type_,
        "content": f"Test {type_} at {lat:.4f}, {lng:.4f}",
        "latitude": lat,
        "longitude": lng,
        "address": "Test Address",
        "created_at": int(time.time() * 1000)
    }).encode()
    
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header('Content-Type', 'application/json')
    req.add_header('Authorization', f'Bearer {token}')
    
    try:
        with urllib.request.urlopen(req) as response:
            print(f"Created feedback: {response.getcode()}")
    except Exception as e:
        print(f"Create feedback failed: {e}")

def create_sos(token, lat, lng):
    url = f"{BASE_URL}/messages/sos"
    data = json.dumps({
        "latitude": lat,
        "longitude": lng,
        "message": "Help me! Test SOS."
    }).encode()
    
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header('Content-Type', 'application/json')
    req.add_header('Authorization', f'Bearer {token}')
    
    try:
        with urllib.request.urlopen(req) as response:
            print(f"Created SOS: {response.getcode()}")
    except Exception as e:
        print(f"Create SOS failed: {e}")

def main():
    print("Seeding map data...")
    token = get_token("user1", "password")
    if not token:
        return

    # Create 5 random feedbacks
    types = ["blocked", "weather", "supply", "danger", "other"]
    for _ in range(5):
        lat = CENTER_LAT + (random.random() - 0.5) * 0.05
        lng = CENTER_LNG + (random.random() - 0.5) * 0.05
        create_feedback(token, lat, lng, random.choice(types))

    # Create 2 random SOS
    for _ in range(2):
        lat = CENTER_LAT + (random.random() - 0.5) * 0.05
        lng = CENTER_LNG + (random.random() - 0.5) * 0.05
        create_sos(token, lat, lng)

    print("Done seeding.")

if __name__ == "__main__":
    main()
