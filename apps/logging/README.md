# Logging
Logging deploys a Fluent Bit-based logging stack that includes Elasticsearch and Kibana. Unlike other apps that deploy multiple components (e.g., kube-prometheus-stack, Airflow) as part of a single external Chart, logging depends on multiple external Charts, each deploying one of the components.

Fluent Bit is a lightweight log processor and forwarder. It runs as a DaemonSet on every node and generates, processes, and forwards logs as configured. In this project, Fluent Bit is configured to tail container log files, to process the logs as Kubernetes-generated logs (i.e., they are enriched with Kubernetes-specific metadata such as Pod labels and other metadata), and to forward them to Elasticsearch. Fluent Bit can also be configured to generate logs containing various metrics (e.g., CPU, memory, disk I/O, network I/O) or to emit them to multiple sinks (e.g., Kafka, InfluxDB).

Additionally, logging-sidecar-test is a Pod that is configured to run Fluent Bit as a sidecar container with its own configuration, forwarding logs from a Pod-wide shared volume to Elasticsearch. In this case, the logs are still enriched with some metadata (e.g., Pod name, namespace, node, and app name), but must be enriched manually (see the record_modifier filter under fluentBitSidecar.config in values.yaml; this is in contrast with the automatic enrichment done by the kubernetes filter under fluent-bit.config.filters). As logs in this case are written directly to the shared volume and not to stdout or stderr and thus do not appear in the container log files, the DaemonSet-managed Fluent Bits will not pick them up.

Elasticsearch is a distributed document store with search and analytics capabilities. It is commonly used for storing and searching for documents such as logs, though it also supports many other data types (e.g., metrics, geospatial data). Production Elasticsearch clusters often consist of separate master and data nodes that handle cluster metadata (e.g., cluster membership, index management, shard assignment) and data operations (e.g., indexing and storage, search, aggregation), respectively. There are a few more specialized roles that nodes can assume to further separate responsibilities as needed as the cluster grows. In this project, our Elasticsearch nodes (i.e., Elasticsearch Pods, not to be confused with Kubernetes nodes) double as both master and data nodes because of the experimental nature of the cluster.

The Elasticsearch Chart deploys Elasticsearch as a StatefulSet, which allows each Pod to maintain a consistent identity between restarts (unlike with Deployments or DaemonSets). This not only allows an Elasticsearch Pod to remount the same Persistent Volume that it had mounted before being rescheduled, but also allows it to rejoin the cluster with the same node identity. It is important that the rejoining node has the same identity otherwise the cluster will treat it as a new node while believing the previous node is unreachable instead of marking the previous node as having recovered, affecting the cluster membership list, which can have many downstream effects (e.g., quorum calculations, replica placement).

Although one does not need to define a schema for documents stored in Elasticsearch (the system can generate a mapping based on the documents it receives), one can manually create a mapping for more fine-grained control over the index's behaviour (e.g., the types of specifics fields, limits on the number of fields or depth of nested fields, whether requests containing documents not conforming to the schema should be failed or the non-conforming documents dropped, whether a field should be indexed and how it should be indexed).

Although we rely on the dynamically generated mapping in this project, the type-checking behaviour of the indexer causes some problems. The label and annotation fields that are automatically added to each document by the kubernetes filter of Fluent Bit lead to collisions as label keys with "." in them are treated as being nested (i.e., "a.b" is treated as key "b" being nested under key "a"), which leads to collisions when one document has a label with key "app" and another has a label with key "app.kubernetes.io/instance". The dynamically generated mapping will thus set the type of the value of "app" to either string or object, depending on whether the first document it indexes contains "app" or "app.kubernetes.io/instance", respectively. Subsequent documents containing the other key will then fail the type check and the requests containing them will be failed (the default behaviour). To resolve this, we use a Fluent Bit filter that calls a Lua script to replace all "." (and "/") characters in keys with "_".

Kibana is the UI component of the Elasticsearch ecosystem and provides a UI for users to explore and visualize the data in Elasticsearch including cluster metadata. In addition to running ad hoc queries, users can create graphs, charts, tables, etc. based on queries on the data. These can then be saved as dashboards for continuous display or shared with others.

The Elasticsearch ecosystem also contains an assortment of tools to ingest, transform, and emit data - similar to Fluent Bit (e.g., Filebeat tails files and forwards lines, Metricbeat emits host metrics, Logstash can process the streamed data prior to forwarding it to Elasticsearch or another sink). A major benefit of staying within the Elasticsearch ecosystem are the existing end-to-end integrations. For example, Metricbeat has modules for acquiring source-specific metrics (i.e., from Prometheus, etcd, Kafka, etc.) while Kibana has pre-built visualizations for them.

Examples of things to experiment with:

- testing other Fluent Bit configurations (e.g., additional metrics and processing, log parsing, multiline log parsing, selectively including logs from specific containers within a Pod)
- using StatefulSets to ensure consistent volume-Pod mappings and identities that survive Pod rescheduling
- how PersistentVolumeClaims and PersistentVolumes interact to persist data between Pod lifetimes
- how volumeClaimTemplates interact with PersistentVolume Provisioners to dynamically create Persistent Volumes
- exploring Elasticsearch data with Kibana
- understanding Elasticsearch internals (e.g., indices and indexing, shards, query routing)
- investigating Elasticsearch index configurations (e.g., document mappings, time-based index rotation)
- integrating other components of the Elasticsearch ecosystem (e.g., Filebeat, Metricbeat)
- using a Fluent Bit sidecar to direct logs from the same container to different indices

## Testing
One can test a Fluent Bit configuration locally before rolling it out. We've provided example configurations ("filter_test.conf" and "parser_test.conf") that can be tested locally by running `fluent-bit -c apps/logging/<filename>`. It is important to note that the parser modifies the timestamp associated with logs it processes to be the timestamp contained within the log itself (i.e. the time at which the log was generated) whereas, by default, the timestamp used is the time at which the log was processed by Fluent Bit.

If kube-prometheus-stack is running, Fluent Bit metrics will be viewable in Prometheus. If not, it is still possible to view any individual instance's metrics by port forwarding to the given instance (`kubectl port-forward <Pod name> -n kube-system <local port>:<the Fluent Bit server's configured port; the default is 2020>`) and then running `curl localhost:<local port>/api/v1/metrics` to get the metrics in JSON format or `curl localhost:<local port>/api/v1/metrics/prometheus` to get the metrics in Prometheus format. This works for both the DaemonSet-managed Fluent Bits as well as the sidecar Fluent Bit.

If nginx-ingress is running, Kibana can be reached at `http://localhost/kibana`. From here, we can explore the Elasticsearch cluster's metrics (e.g., overall and per-index indexing and search rate and latency, node CPU, memory, and disk usage, index size and shard and partition count and allocation) from Stack Monitoring. To explore (or modify) index settings (e.g., document mapping, shard and replica counts), go to Stack Management -> Index Management and select the index of interest.

To search the logs emitted by Fluent Bit and indexed by Elasticsearch, one must first define an Index Pattern (from Stack Management -> Index Patterns). An Index Pattern is a regex that describes which Elasticsearch indices should be searched. Since we've configured our Fluent Bit to dump logs into "fluent-general-YYYY.MM.DD", "fluent-system-YYYY.MM.DD", or "fluent-special-YYYY.MM.DD" indices (logs from Pods annotated with `loggingTag: special` are dumped into "fluent-special", remaining logs from the "kube-system" namespace are dumped into "fluent-system", and remaining logs from all other namespaces are dumped into the "fluent-general"), we will create four Index Patterns with the following regexes: "fluent-\*", "fluent-general-\*", "fluent-system-\*", "fluent-special-\*". These will search all logs, logs from all non-"kube-system" namespaces (from Pods that aren't annotated with `loggingTag: special`), logs from the "kube-system" namespace (again, from Pods that aren't annotated with `loggingTag: special`), and logs from Pods annotated with `loggingTag: special`, respectively. Now, with the Index Patterns we just created, in Discover, we can use a query like `kubernetes.labels.app:kibana` to search for logs from Pods with the label "app=kibana". Since Kibana runs in the "kube-system" namespace and is not annotated with `loggingTag: special`, we'd expect to find its logs using the "fluent-\*" or "fluent-system-\*", but not "fluent-general-\*" or "fluent-special-\*", Patterns. (logging-sidecar-test in this app is the only Pod currently annotated with `loggingTag: special` and so stdout and stderr output from that Pod should be the only logs present in fluent-special-\*)

Additionally, we use Fluent Bit annotations to selectively include logs from specific containers within a Pod. We have a Deployment in the `kube-system` namespace that creates a Pod that contains `default`, `public`, and `excluded` containers and `fluentbit.io/exclude: "true"`, `fluentbit.io/exclude-default: "false"`, and `fluentbit.io/exclude-public: "false"` annotations. These annotations result in Fluent Bit excluding, by default, logs from this Pod, with the exception of logs from the `default` and `public` containers. What's more, although logs from this Pod generally go to "fluent-system" index (as described above), the container name-based routing routes logs from the `public` container to the "fluent-public" index (we can search this index using the "fluent-public-\*" Index Pattern).

To search for logs emitted by the sidecar Fluent Bit, we can use Index Patterns with the following regexes: "sidecar-\*", "sidecar-public-\*", and "sidecar-protected-\*". The log-generator container creates two log files, one under /logs/public and one under /logs/protected, and the sidecar Fluent Bit is configured to send logs from /logs/public/\*.log to "sidecar-public-YYYY.MM.DD" and from /logs/protected/\*.log to "sidecar-protected-YYYY.MM.DD". The log file created in /logs/public emulate multiline logs with the first line of a multiline log starting with a timestamp in "%d/%m/%Y %H:%M:%S - \<message>" format. Fluent Bit is then configured to use "^\d+\/\d+\/\d+ \d+\:\d+\:\d+ - (?<log>.*)$" as a regex to match this and aggregate multiple lines into a single log, which can be seen in Kibana. Remember, since these logs are written to a file that the sidecar Fluent Bit tails and not to stdout or stderr, they are not picked up by the DaemonSet-managed Fluent Bits that write to the "fluent-\*" indices (though the app does output two lines, one to stdout and one to stderr, that will show up in "fluent-special-\*").

The multiline log aggregation above is simpler than in most real-world cases since the logs are written raw to the file tailed by Fluent Bit. In the real world, logs are often printed to stdout or stderr, picked up by the container runtime, and augmented with metadata before being written to the file tailed by Fluent Bit. So whereas a log in the above example might look like

```
This is a line
```

, the same line logged through the container runtime might look like

```
{"log":"This is a line\n","stream":"stdout","time":"2021-10-29T22:07:56.594970641Z"}
```

This makes it difficult to aggregate these container runtime-processed multiline logs the same way as above. Instead, there is a special setting for aggregating Docker-processed multiline logs (there doesn't seem to be an equivalent for cri-processed multiline logs). An example can be found in "parser_test.conf".

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
