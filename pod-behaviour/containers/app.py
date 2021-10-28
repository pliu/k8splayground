from __future__ import print_function
import argparse
import signal
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument('--sigint', dest='sigint', help='Terminate on SIGINT instead of SIGTERM', action='store_true')
parser.add_argument('--timed', dest='timed', help='Terminate after a 60s logged countdown instead of immediately', action='store_true')
parser.add_argument('--error', dest='error', help='Exits with non-zero exit code', action='store_true')
parser.set_defaults(sigint=False, timed=False, error=False)
args = parser.parse_args()


def exitHelper():
    if args.timed:
        for i in range(30):
            time.sleep(1)
            print(time.strftime("%H:%M:%S", time.localtime()))
        time.sleep(30)
        print(time.strftime("%H:%M:%S", time.localtime()))
        exit(0 if not args.error else 1)
    exit(0 if not args.error else 1)


def receiveSignal(signalNumber, frame):
    print("Received", signalNumber)
    if not args.sigint and signalNumber == signal.SIGTERM :
        exitHelper()
    elif args.sigint and signalNumber == signal.SIGINT:
        exitHelper()


if __name__ == '__main__':
    signal.signal(signal.SIGHUP, receiveSignal)
    signal.signal(signal.SIGINT, receiveSignal)
    signal.signal(signal.SIGQUIT, receiveSignal)
    signal.signal(signal.SIGILL, receiveSignal)
    signal.signal(signal.SIGTRAP, receiveSignal)
    signal.signal(signal.SIGABRT, receiveSignal)
    signal.signal(signal.SIGBUS, receiveSignal)
    signal.signal(signal.SIGFPE, receiveSignal)
    # Can't register handler for SIGKILL
    # signal.signal(signal.SIGKILL, receiveSignal)
    signal.signal(signal.SIGUSR1, receiveSignal)
    signal.signal(signal.SIGSEGV, receiveSignal)
    signal.signal(signal.SIGUSR2, receiveSignal)
    signal.signal(signal.SIGPIPE, receiveSignal)
    signal.signal(signal.SIGALRM, receiveSignal)
    signal.signal(signal.SIGTERM, receiveSignal)
    print('SIGINT' if args.sigint else 'SIGTERM')
    print('Timed exit' if args.timed else 'Immediate exit')
    print('Non-zero exit code' if args.error else 'Zero exit code')
    while True:
        time.sleep(30)
