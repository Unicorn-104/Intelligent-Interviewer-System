"""Loopback-only FastEmbed adapter for the C-App personal-memory Qdrant index."""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from threading import Lock

MODEL_NAME = os.environ.get("MEMORY_EMBEDDING_MODEL", "BAAI/bge-small-zh-v1.5")
HOST = os.environ.get("MEMORY_EMBEDDING_HOST", "127.0.0.1")
PORT = int(os.environ.get("MEMORY_EMBEDDING_PORT", "8091"))
TOKEN = os.environ.get("MEMORY_EMBEDDING_TOKEN", "")
_model = None
_model_lock = Lock()


def get_model():
    global _model
    if _model is None:
        with _model_lock:
            if _model is None:
                from fastembed import TextEmbedding
                _model = TextEmbedding(model_name=MODEL_NAME,
                                       cache_dir=os.environ.get("MEMORY_EMBEDDING_CACHE_DIR") or None)
    return _model


class Handler(BaseHTTPRequestHandler):
    server_version = "CAppMemoryEmbedding/1"

    def do_GET(self):
        if self.path != "/health":
            self.send_error(404)
            return
        self._json(200, {"status": "ok", "model": MODEL_NAME})

    def do_POST(self):
        if self.path != "/v1/embeddings":
            self.send_error(404)
            return
        if TOKEN and self.headers.get("Authorization") != "Bearer " + TOKEN:
            self.send_error(401)
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if size < 2 or size > 65536:
                self.send_error(413)
                return
            request = json.loads(self.rfile.read(size))
            texts = request.get("input")
            input_type = request.get("input_type", "passage")
            if not isinstance(texts, list) or not 1 <= len(texts) <= 16:
                self.send_error(400)
                return
            if any(not isinstance(text, str) or not text.strip() or len(text) > 2000 for text in texts):
                self.send_error(400)
                return
            if input_type not in ("query", "passage"):
                self.send_error(400)
                return
            model = get_model()
            if input_type == "query" and hasattr(model, "query_embed"):
                vectors = model.query_embed(texts)
            elif input_type == "passage" and hasattr(model, "passage_embed"):
                vectors = model.passage_embed(texts)
            else:
                vectors = model.embed(texts)
            data = [
                {"object": "embedding", "index": index, "embedding": vector.tolist()}
                for index, vector in enumerate(vectors)
            ]
            self._json(200, {"object": "list", "model": MODEL_NAME, "data": data})
        except Exception as error:
            # Deliberately omit request text and exception details from the response/log.
            print("embedding request failed:", type(error).__name__, flush=True)
            self.send_error(503, "embedding unavailable")

    def _json(self, status, value):
        body = json.dumps(value, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format_string, *args):
        print("embedding http:", args[1] if len(args) > 1 else "request", flush=True)


if __name__ == "__main__":
    if HOST not in ("127.0.0.1", "localhost", "::1"):
        raise SystemExit("Embedding service must bind to loopback only")
    if os.environ.get("MEMORY_EMBEDDING_PRELOAD", "false").lower() == "true":
        get_model()
    print(f"Starting local embedding service on {HOST}:{PORT} using {MODEL_NAME}", flush=True)
    HTTPServer((HOST, PORT), Handler).serve_forever()
