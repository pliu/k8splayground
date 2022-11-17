# confluent-for-kubernetes


Examples of things to experiment with:

- how does confluent-for-kubernetes roll upgrades out


## Testing


## Commands
```
Apply/update confluent-for-kubernetes:
make confluent_apply

Delete confluent-for-kubernetes:
make confluent_delete

Build plugins, put into image, and push image to workers:
make confluent_plugins_build

Create topic:
/kafka-topics.sh --bootstrap-server localhost:31000 --command-config apps/confluent-for-kubernetes/files/kafka.properties --topic <topic name> --create

Add ACL entry:
./kafka-acls.sh --bootstrap-server localhost:31000 --command-config apps/confluent-for-kubernetes/files/kafka.properties --add --allow-principal "User:test2" --operation Write --topic <topic name>

./kafka-acls.sh --bootstrap-server localhost:31000 --command-config apps/confluent-for-kubernetes/files/kafka.properties --add --allow-principal "User:test2" --operation Write --topic <topic name>
```
