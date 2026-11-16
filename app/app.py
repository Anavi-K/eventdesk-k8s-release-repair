import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ('/ready', '/live'):
            body = {'status': 'ok'}
        elif self.path == '/api/events':
            body = {'events': ['Campus club fair'],
                    'APP_ENV': os.getenv('APP_ENV', 'development'),
                    'BANNER': os.getenv('BANNER', 'EventDesk preview'),
                    'DEMO_TOKEN_PRESENT': bool(os.getenv('DEMO_TOKEN'))}
        else:
            self.send_error(404)
            return
        data = json.dumps(body).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

HTTPServer(('0.0.0.0', 8000), Handler).serve_forever()
