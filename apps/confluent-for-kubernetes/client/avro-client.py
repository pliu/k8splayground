import asyncio
from dataclasses import asdict, dataclass, field
import json
import random

from confluent_kafka import avro, Consumer, Producer
from confluent_kafka.avro import AvroConsumer, AvroProducer, CachedSchemaRegistryClient
from faker import Faker

faker = Faker()
SCHEMA_REGISTRY_URL = "http://localhost:31010"
BROKER_URL = "PLAINTEXT://localhost:31000"

@dataclass
class Purchase:
    username: str = field(default_factory=faker.user_name)
    currency: str = field(default_factory=faker.currency_code)
    amount: int = field(default_factory=lambda: random.randint(100, 200000))

    schema = avro.loads(
        """{
        "type": "record",
        "namespace": "com.example.purchase",
        "name": "AvroFakePurchase",
        "fields": [
            {"name": "username", "type": "string"},
            {"name": "currency", "type": "string"},
            {"name": "amount", "type": "int"}
        ]
    }"""
    )

