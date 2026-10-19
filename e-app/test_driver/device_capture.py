"""Local screenshot bridge for Pixel_10a integration tests; no app data is read."""
import json
import os
import shutil
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

def find_adb():
    executable = shutil.which("adb")
    if executable:
        return executable
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not sdk:
        properties = Path(__file__).resolve().parents[1] / "android/local.properties"
        if properties.exists():
            for line in properties.read_text(encoding="utf-8").splitlines():
                if line.startswith("sdk.dir="):
                    sdk = line.split("=", 1)[1].replace("\\:", ":").replace("\\\\", "\\")
                    break
    if sdk:
        candidate = Path(sdk) / "platform-tools" / ("adb.exe" if os.name == "nt" else "adb")
        if candidate.exists():
            return str(candidate)
    raise RuntimeError("Add adb to PATH or set ANDROID_HOME before running the device audit")


ADB = find_adb()
DEVICE = "emulator-5554"
OUTPUT = Path(__file__).resolve().parents[1] / "build/stage-one-device/screenshots"


def adb(*args):
    return subprocess.check_output([ADB, "-s", DEVICE, *args], timeout=15)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            if self.path.startswith("/capture/"):
                name = self.path.removeprefix("/capture/")
                if not re.fullmatch(r"[A-Za-z0-9_]+", name):
                    self.send_error(400)
                    return
                OUTPUT.mkdir(parents=True, exist_ok=True)
                (OUTPUT / (name + ".png")).write_bytes(adb("exec-out", "screencap", "-p"))
            elif self.path.startswith("/layout/"):
                layout = self.path.removeprefix("/layout/")
                if layout == "narrow":
                    adb("shell", "wm", "size", "840x1680")
                elif layout in ("portrait", "landscape", "reset"):
                    adb("shell", "wm", "size", "reset")
                    adb("shell", "settings", "put", "system", "accelerometer_rotation", "0")
                    adb("shell", "settings", "put", "system", "user_rotation", "1" if layout == "landscape" else "0")
                else:
                    self.send_error(400)
                    return
            else:
                self.send_error(404)
                return
            data = json.dumps({"ok": True}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception as error:
            self.send_error(500, type(error).__name__)

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    print("Pixel_10a screenshot bridge listening on 127.0.0.1:18989", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 18989), Handler).serve_forever()
