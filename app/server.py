#!/usr/bin/env python3
"""
Simple HTTP server that displays X-Forwarded-For header value.
Used to demonstrate nginx proxy chain handling.
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os

class ForwardedForHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Get X-Forwarded-For header
        x_forwarded_for = self.headers.get('X-Forwarded-For', 'not present')
        x_real_ip = self.headers.get('X-Real-IP', 'not present')
        remote_addr = self.client_address[0]
        
        # Build response
        response = {
            'client_ip': remote_addr,
            'x_forwarded_for': x_forwarded_for,
            'x_real_ip': x_real_ip,
            'all_headers': dict(self.headers)
        }
        
        # Send response
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response, indent=2).encode())
    
    def log_message(self, format, *args):
        # Suppress logging for cleaner output
        pass

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    server = HTTPServer(('0.0.0.0', port), ForwardedForHandler)
    print(f'Server running on port {port}...')
    server.serve_forever()
