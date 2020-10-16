# Logging
Logging deploys a Fluent Bit-based logging stack that includes Elasticsearch and Kibana. Unlike other apps that deploy multiple components (e.g., Prometheus Operator, Airflow) as part of a single external Chart, logging depends on multiple external Charts, each deploying one of the components.

Fluent Bit is a lightweight log processor and forwarder. It runs as a Daemon Set on every node and generates, processes, and forwards logs as configured. In this project, Fluent Bit is configured to tail container log files, to process the logs as Kubernetes-generated logs (i.e., they are enriched with Kubernetes-specific metadata such as Pod labels and other metadata), and to forward them to Elasticsearch. Fluent Bit can also be configured to generate logs containing various metrics (e.g., CPU, memory, disk I/O, network I/O) or to emit them to multiple sinks (e.g., Kafka, InfluxDB).

Elasticsearch is a distributed document store with search and analytics capabilities. It is commonly used for storing and searching for documents such as logs, though it also supports many other data types (e.g., metrics, geospatial data). Production Elasticsearch clusters often consist of separate master and data nodes that handle cluster metadata (e.g., cluster membership, index management, shard assignment) and data operations (e.g., indexing and storage, search, aggregation), respectively. There are a few more specialized roles that nodes can assume to further separate responsibilities as needed as the cluster grows. In this project, our Elasticsearch nodes (i.e., Elasticsearch Pods, not to be confused with Kubernetes nodes) double as both master and data nodes because of the experimental nature of the cluster.

The Elasticsearch Chart deploys Elasticsearch as a StatefulSet, which allows each Pod to maintain a consistent identity between restarts (unlike with Deployments or DaemonSets). This not only allows an Elasticsearch Pod to remount the same Persistent Volume that it had mounted before being rescheduled, but also allows it to rejoin the cluster with the same node identity. It is important that the rejoining node has the same identity otherwise the cluster will treat it as a new node while believing the previous node is unreachable instead of marking the previous node as having recovered, affecting the cluster membership list, which can have many downstream effects (e.g., quorum calculations, replica placement).

Although one does not need to define a schema for documents stored in Elasticsearch (the system can generate a mapping based on the documents it receives), one can manually create a mapping for more fine-grained control over the index's behaviour (e.g., the types of specifics fields, limits on the number of fields or depth of nested fields, whether requests containing documents not conforming to the schema should be failed or the non-conforming documents dropped, whether a field should be indexed and how it should be indexed).

Although we rely on the dynamically generated mapping in this project, the type-checking behaviour of the indexer causes some problems. The label and annotation fields that are automatically added to each document by the kubernetes filter of Fluent Bit lead to collisions as label keys with "." in them are treated as being nested (i.e., "a.b" is treated as key "b" being nested under key "a"), which leads to collisions when one document has a label with key "app" and another has a label with key "app.kubernetes.io/instance". The dynamically generated mapping will thus set the type of the value of "app" to either string or object, depending on whether the first document it indexes contains "app" or "app.kubernetes.io/instance", respectively. Subsequent documents containing the other key will then fail the type check and the requests containing them will be failed (the default behaviour). To resolve this, we use a Fluent Bit filter that calls a Lua script to replace all "." (and "/") characters in keys with "_".

Kibana is the UI component of the Elasticsearch ecosystem and provides a UI for users to explore and visualize the data in Elasticsearch including cluster metadata. In addition to running ad hoc queries, users can create graphs, charts, tables, etc. based on queries on the data. These can then be saved as dashboards for continuous display or shared with others.

The Elasticsearch ecosystem also contains an assortment of tools to ingest, transform, and emit data - similar to Fluent Bit (e.g., Filebeat tails files and forwards lines, Metricbeat emits host metrics, Logstash can process the streamed data prior to forwarding it to Elasticsearch or another sink). A major benefit of staying within the Elasticsearch ecosystem are the existing end-to-end integrations. For example, Metricbeat has modules for acquiring source-specific metrics (i.e., from Prometheus, etcd, Kafka, etc.) while Kibana has pre-built visualizations for them.

Examples of things to experiment with:

- testing other Fluent Bit configurations (e.g., additional metrics and processing)
- using StatefulSets to ensure consistent volume-Pod mappings and identities that survive Pod rescheduling
- how PersistentVolumeClaims and PersistentVolumes interact to persist data between Pod lifetimes
- how volumeClaimTemplates interact with PersistentVolume Provisioners to dynamically create Persistent Volumes
- exploring Elasticsearch data with Kibana
- understanding Elasticsearch internals (e.g., indices and indexing, shards, query routing)
- investigating Elasticsearch index configurations (e.g., document mappings, time-based index rotation)
- integrating other components of the Elasticsearch ecosystem (e.g., Filebeat, Metricbeat)

## Testing
One can test a Fluent Bit configuration locally before rolling it out. We've provided an example configuration ("test.conf") that can be tested locally by running `fluent-bit -c apps/logging/test.conf`.

If prometheus-operator is running, Fluent Bit metrics will be viewable in Prometheus. If not, it is still possible to view any individual instance's metrics by port forwarding to the given instance (`kubectl port-forward <Pod name> -n kube-system <local port>:<the Fluent Bit server's configured port; the default is 2020>`) and then running `curl localhost:<local port>/api/v1/metrics` to get the metrics in JSON format or `curl localhost:<local port>/api/v1/metrics/prometheus` to get the metrics in Prometheus format.

If nginx-ingress is running, Kibana can be reached at `http://localhost/kibana`. From here, we can explore the Elasticsearch cluster's metrics (e.g., overall and per-index indexing and search rate and latency, node CPU, memory, and disk usage, index size and shard and partition count and allocation) from Stack Monitoring. To explore (or modify) index settings (e.g., document mapping, shard and replica counts), go to Stack Management -> Index Management and select the index of interest.

To search the logs emitted by Fluent Bit and indexed by Elasticsearch, one must first define an Index Pattern (from Stack Management -> Index Patterns). An Index Pattern is a regex that describes which Elasticsearch indices should be searched. Since we've configured our Fluent Bit to dump logs into either "fluent-general-YYYY.MM.DD" or "fluent-system-YYYY.MM.DD" indices (logs from the "kube-system" namespace are dumped into the latter while logs from all other namespaces are dumped into the former), we will create three Index Patterns with the following regexes: "fluent-\*", "fluent-general-\*", and "fluent-system-\*". These will search all logs, logs from all non-"kube-system" namespaces, and logs from the "kube-system" namespace, respectively.Now, with the Index Patterns we just created, in Discover, we can use a query like `kubernetes.labels.app:kibana` to search for logs from Pods with the label "app=kibana". Since Kibana runs in the "kube-system" namespace, we'd expect to find its logs using the "fluent-\*" or "fluent-system-\*", but not "fluent-general-\*", Pattern.

## Commands
```
Apply/update logging:
make logging_apply

Delete logging:
make logging_delete

Delete persisted data (after Pods are deleted):
kubectl delete pvc -l app=elasticsearch-master -n kube-system

Test local Fluent Bit config:
fluent-bit -c <path to config to test>
```
