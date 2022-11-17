from confluent_kafka import Producer

import random
import string
import time


conf = {
    "bootstrap.servers": "localhost:31000",
    "security.protocol": "SASL_PLAINTEXT",
    "sasl.mechanism": "PLAIN",
    "sasl.username": "test1",
    "sasl.password": "password1",
    "enable.idempotence": True,
    "acks": "all",
}

def get_string(min_length, max_length):
    length = random.randint(min_length, max_length)
    return ''.join(random.choices(string.ascii_uppercase +string.ascii_lowercase + string.digits, k=length))


def failure_callback(err, msg):
    print(err, msg)


start = time.time()
producer = Producer(conf)
for i in range(2000):
    producer.produce(topic="test-topic", value=get_string(51, 81), on_delivery=failure_callback)
    producer.poll()
producer.flush()
producer.poll()
end = time.time()
print(end - start)
