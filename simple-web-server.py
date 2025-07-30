#!/usr/bin/env python3
import http.server
import socketserver
import os

PORT = 3005

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.path = '/simple-sofia-web.html'
        elif self.path == '/api/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status":"ok","service":"sofia-web"}')
            return
        return http.server.SimpleHTTPRequestHandler.do_GET(self)

os.chdir('/home/elo/elo-deu')

with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
    print(f"Sofia Web Interface running at http://localhost:{PORT}")
    httpd.serve_forever()