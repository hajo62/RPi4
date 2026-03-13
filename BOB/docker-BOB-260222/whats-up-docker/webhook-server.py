#!/usr/bin/env python3

"""
WUD Webhook Server - Python HTTP Server
Empfängt Webhooks von WUD und führt send_signal.sh aus
"""

import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime
from zoneinfo import ZoneInfo

PORT = 8091
SCRIPT_PATH = "/scripts/send_signal.sh"
TIMEZONE = os.getenv('TZ', 'Europe/Berlin')

def log(message):
    """Log mit Timestamp in korrekter Zeitzone"""
    try:
        tz = ZoneInfo(TIMEZONE)
        timestamp = datetime.now(tz).strftime('%Y-%m-%d %H:%M:%S')
    except Exception:
        # Fallback wenn Zeitzone nicht verfügbar
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {message}", flush=True)

class WebhookHandler(BaseHTTPRequestHandler):
    """HTTP Request Handler für Webhooks"""
    
    def log_message(self, format, *args):
        """Überschreibe Standard-Logging"""
        pass  # Wir nutzen unsere eigene log() Funktion
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/health':
            log("Health check received")
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = json.dumps({"status": "healthy"})
            self.wfile.write(response.encode())
        else:
            log(f"Unknown GET request: {self.path}")
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        """Handle POST requests"""
        if self.path == '/webhook':
            try:
                # Lese Request Body
                content_length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(content_length)
                data = json.loads(body.decode('utf-8'))
                
                log("Webhook received")
                
                # Extrahiere Container-Informationen aus WUD's Standard-Format
                # WUD sendet: {id, name, watcher, image, result, updateAvailable, ...}
                container_name = data.get('name', 'unknown')
                
                # Extrahiere aktuelle Version aus image.tag.value
                image_data = data.get('image', {})
                current_version = image_data.get('tag', {}).get('value', 'unknown')
                
                # Extrahiere neue Version aus result.tag
                result_data = data.get('result', {})
                if isinstance(result_data, dict):
                    new_version = result_data.get('tag', 'unknown')
                else:
                    # Fallback: Versuche updateAvailable
                    update_data = data.get('updateAvailable', {})
                    if isinstance(update_data, dict):
                        new_version = update_data.get('tag', 'unknown')
                    else:
                        new_version = 'unknown'
                
                log(f"Container: {container_name}")
                log(f"Current: {current_version} → New: {new_version}")
                
                # Führe Script aus
                log("Executing script...")
                try:
                    result = subprocess.run(
                        ['bash', SCRIPT_PATH, container_name, current_version, new_version],
                        capture_output=True,
                        text=True,
                        timeout=30
                    )
                    
                    if result.returncode == 0:
                        log("Script executed successfully")
                        log(f"Output: {result.stdout.strip()}")
                    else:
                        log(f"ERROR: Script failed with code {result.returncode}")
                        log(f"Error: {result.stderr.strip()}")
                    
                    # Sende Success Response
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    response = json.dumps({
                        "success": result.returncode == 0,
                        "container": container_name,
                        "currentVersion": current_version,
                        "newVersion": new_version
                    })
                    self.wfile.write(response.encode())
                    
                except subprocess.TimeoutExpired:
                    log("ERROR: Script execution timed out")
                    self.send_response(500)
                    self.end_headers()
                    
                except Exception as e:
                    log(f"ERROR: Script execution failed: {e}")
                    self.send_response(500)
                    self.end_headers()
                
            except json.JSONDecodeError as e:
                log(f"ERROR: Invalid JSON: {e}")
                self.send_response(400)
                self.end_headers()
                
            except Exception as e:
                log(f"ERROR: Request handling failed: {e}")
                self.send_response(500)
                self.end_headers()
        else:
            log(f"Unknown POST request: {self.path}")
            self.send_response(404)
            self.end_headers()

def main():
    """Start HTTP Server"""
    log(f"Starting webhook server on port {PORT}")
    log(f"Script path: {SCRIPT_PATH}")
    
    server = None
    try:
        server = HTTPServer(('0.0.0.0', PORT), WebhookHandler)
        log("Webhook server ready")
        server.serve_forever()
    except KeyboardInterrupt:
        log("Shutting down...")
        if server:
            server.shutdown()
        sys.exit(0)
    except Exception as e:
        log(f"ERROR: Server failed to start: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()

# Made with Bob
