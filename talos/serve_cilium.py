from http.server import SimpleHTTPRequestHandler, HTTPServer
import os

class SingleRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.getcwd(), **kwargs)

    def do_GET(self):
        if self.path == '/cilium.yaml':
            super().do_GET()
            print("File has been downloaded. Shutting down the server.")
            global done
            done = True
        else:
            self.send_error(404, "File not found")

if __name__ == "__main__":
    PORT = 8000
    handler = SingleRequestHandler
    global done
    done = False
    with HTTPServer(("", PORT), handler) as httpd:
        print(f"Serving cilium.yaml on port {PORT}")
        while not done:
            httpd.handle_request()