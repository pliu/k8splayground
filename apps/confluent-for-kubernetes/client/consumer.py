from confluent_kafka import Consumer
from confluent_kafka import KafkaError
from confluent_kafka import KafkaException

import time


conf = {
    "bootstrap.servers": "localhost:31000",
    "group.id": "test1",
    "auto.offset.reset": "earliest",
    "enable.auto.commit": True,
    "security.protocol": "SASL_PLAINTEXT",
    "sasl.mechanism": "PLAIN",
    "sasl.username": "test1",
    "sasl.password": "password1",
}

consumer = Consumer(conf)

try:
    consumer.subscribe(["test-topic"])

    while True:
        msg = consumer.poll(timeout=1.0)
        if msg is None: continue

        if msg.error():
            if msg.error().code() == KafkaError._PARTITION_EOF:
                # End of partition event
                sys.stderr.write('%% %s [%d] reached end at offset %d\n' %
                                    (msg.topic(), msg.partition(), msg.offset()))
            elif msg.error():
                raise KafkaException(msg.error())
        else:
            print(msg.key(), msg.value(), msg.topic(), msg.partition(), msg.timestamp())
finally:
    # Close down consumer to commit final offsets.
    consumer.close()
