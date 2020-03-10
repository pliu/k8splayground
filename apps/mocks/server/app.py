from __future__ import print_function
import signal
import sys
from flask import Flask, request

app = Flask(__name__)

def receiveSignal(signalNumber, frame):
    print("Received", signalNumber, file=sys.stderr)
    exit(0)

@app.route('/', methods=['GET', 'POST'])
def hello_world():
    data = request.data
    if data:
       print(data, file=sys.stderr)
    return 'Hey, we have Flask in a Docker container!'


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, receiveSignal)
    app.run(host='0.0.0.0', port=5000)
