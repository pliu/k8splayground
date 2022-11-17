import subprocess

cmd = ["/usr/bin/kafkacat", "-X", "security.protocol=SASL_PLAINTEXT", "-X", "sasl.mechanism=PLAIN", "-X", "sasl.username=test1", "-X", "sasl.password=password1", "-L", "-b"]

result = subprocess.run(cmd + ["localhost:31000"], capture_output=True, text=True)
if result.returncode != 0:
    raise Exception("Couldn't get servers")

for line in result.stdout.split("\n"):
    check = line.strip()
    if check.startswith("broker"):
        server = check.split()[3]
        print(server)
        subresult = subprocess.run(cmd + [server], capture_output=True)
        if subresult.returncode != 0:
            raise Exception(f"Could not connect to {server}")
