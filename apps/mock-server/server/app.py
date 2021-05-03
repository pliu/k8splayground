from __future__ import print_function
import json
import signal
import sys
from flask import Flask, request

app = Flask(__name__)


def receiveSignal(signalNumber, frame):
    print("Received", signalNumber, file=sys.stderr)
    exit(0)


@app.route('/', methods=['GET', 'POST'], defaults={'u_path': '/'})
@app.route('/<path:u_path>', methods=['GET', 'POST'])
def payload_dump(u_path):
    data = request.data
    if data:
        try:
            j = json.loads(data)
            print(json.dumps(j), file=sys.stderr)
        except Exception:
            print("Could not parse", data, file=sys.stderr)
    return "You hit: %s" % u_path


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, receiveSignal)
    app.run(host='0.0.0.0', port=5000)
