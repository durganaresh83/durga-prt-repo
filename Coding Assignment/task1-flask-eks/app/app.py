from flask import Flask, jsonify
import os

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(message="Hello from Flask on EKS!", version=os.getenv("APP_VERSION", "dev"))


@app.route("/healthz")
def healthz():
    """Liveness/readiness probe endpoint."""
    return jsonify(status="ok"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
