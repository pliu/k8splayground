from __future__ import print_function
from datetime import datetime
import errno
import os
import signal
import sys
import time


def get_signal_handler(path_prefix):
    def receiveSignal(signalNumber, frame):
        print("Received", signalNumber)
        path3 = path_prefix + "/public/file3.log"
        log_file3 = safe_open_w(path3)
        log_file3.write("Closed\n")
        log_file3.close()
        exit(0)
    return receiveSignal


def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise


def safe_open_w(path):
    ''' Open "path" for writing, creating any parent directories as needed.
    '''
    mkdir_p(os.path.dirname(path))
    return open(path, 'w')


def print_logs(path_prefix):
    path1 = path_prefix + "/protected/file1.log"
    path2 = path_prefix + "/public/file2.log"
    print(path1)
    print(path2, file=sys.stderr)
    log_file1 = safe_open_w(path1)
    log_file2 = safe_open_w(path2)
    log_file2.write(datetime.now().strftime("%d/%m/%Y %H:%M:%S") + " - This is the start\n")
    for i in xrange(100):
        log_file1.write(str(i) + "\n")
        log_file2.write(str(i) + "\n")
    time.sleep(1)
    log_file2.write(datetime.now().strftime("%d/%m/%Y %H:%M:%S") + " - This is the end\n")
    log_file2.write("Next line though\n")
    log_file1.close()
    log_file2.close()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Missing path prefix: " + str(sys.argv))
    path_prefix = sys.argv[1]
    signal.signal(signal.SIGTERM, get_signal_handler(path_prefix))

    print_logs(path_prefix)
    while True:
        time.sleep(1)
