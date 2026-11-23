import os
import socket

from flask import Flask, jsonify
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest

app = Flask(__name__)
REQS = Counter("app_requests_total", "Total requests", ["path"])


@app.route("/")
def index():
    REQS.labels("/").inc()
    return jsonify(
        message="hello from platform-lab",
        host=socket.gethostname(),
        version=os.getenv("APP_VERSION", "dev"),
    )


@app.route("/health")
def health():
    return "ok"


@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}
