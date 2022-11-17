import subprocess

cmd = ["/usr/bin/kafkacat", "-X", "security.protocol=SASL_PLAINTEXT", "-X", "sasl.mechanism=PLAIN", "-X", "sasl.username=test1", "-X", "sasl.password=password1", "-L", "-b"]

result = subprocess.run(cmd + ["localhost:31000"], capture_output=True, text=True)

for line in result.stdout.split("\n"):
    check = line.strip()
    if check.startswith("broker"):
        tokens = check.split()
        subresult = subprocess.run(cmd + [tokens[3]], capture_output=True)
        if subresult.returncode != 0:
            raise Exception("Oh no")
