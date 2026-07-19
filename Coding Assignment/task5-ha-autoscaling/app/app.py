from flask import Flask, jsonify
import hashlib
import os

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(message="HA autoscaling demo", pod=os.getenv("HOSTNAME", "unknown"))


@app.route("/healthz")
def healthz():
    return jsonify(status="ok"), 200


@app.route("/cpu-work")
def cpu_work():
    """CPU-intensive endpoint used to trigger HPA scale-out during load testing."""
    data = b"x" * 100000
    for _ in range(2000):
        data = hashlib.sha256(data).digest()
    return jsonify(status="done")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
