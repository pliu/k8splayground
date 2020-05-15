# Prometheus Operator
Prometheus Operator deploys a Prometheus-based monitoring stack that includes Grafana and Alertmanager. It also includes default metrics exporters, dashboards, and rules (we've included the metrics exporters and dashboards, but disabled the default rules).

Prometheus is a popular time-series database that is used for collecting, processing, and alerting on metrics. Specifically, applications that wish to send metrics to Prometheus expose a metrics endpoint that is periodically scraped by Prometheus exporters (the exporters are configured as part of Prometheus' configuration). Prometheus then applies a set of rules (defined in a set of YAML files) to the metrics for processing and possible alerting.

In the case of alerts being triggered, they are sent to Alertmanager. Alertmanager subsequently preprocesses the alerts (e.g., additional formatting, grouping) and routes them to receivers (e.g., Slack, arbitrary webhook endpoint) based on routing rules defined in its configuration. The routing tree is traversed by recursively matching against the children of the node it last matched, starting at the root, and calling the receiver of the last node it matches. A matched node with continue set to true effectively starts another tree traversal at the node's next sibling as if the matched node had not matched (see alertmanager/alertmanager.yaml for an example). Alertmanager also keeps track of alerts it has received, allowing users to silence superfluous alerts.

Grafana is the visualization component of the Prometheus monitoring and alerting stack. It can connect to a number of data sources, Prometheus amongst them, and render graphs, charts, tables, etc. based on queries on the metrics in the data sources. These can then be saved as dashboards for continuous display or shared with others.

Prometheus Operator automates deployment of the stack by automatically providing the glue that binds the components.

Prometheus' configuration is templated out and configurable through values.yaml. Exporters are configured through ServiceMonitor objects that tie an exporter to the service it is meant to scrape. Similarly, PrometheusRule objects store rules that aggregated into a ConfigMap object that is mounted by the Prometheus instance(s). In this project, PrometheusRule creation is automated based on the rules found in rules/. The base Prometheus Operator chart's default rules have been disabled, but its default exporters are enabled and can be configured in values.yaml.

Alertmanager's configuration (alertmanager/alertmanager.yaml) is rendered into a Secret object which is mounted by the Alertmanager instance(s).

Grafana's configuration can be found in values.yaml. This is rendered by the base Prometheus Operator chart into a ConfigMap object that is mounted by the Grafana instance(s). ConfigMap objects are automatically created based on the dashboards found in dashboards/ and are imported into the Grafana instance(s). The base Prometheus Operator chart's default dashboards have been disabled.

The cluster configuration (kind/config.yaml) changes the metrics bind address for kube-proxy and etcd from the default 127.0.0.1 to 0.0.0.0 so that their respective exporters can scrape their metrics.

The convention for this project is for applications that wish to expose metrics via endpoints to define both their own Service and ServiceMonitor manifests (e.g., nginx-ingress, node-problem-detector). This is because a ServiceMonitor's specification depends on some application-specific context (e.g., Service labels, namespace) which the ServiceMonitors gains access to by being defined in their respective applications. The one exception to this convention is Argo CD: the ServiceMonitors for Argo CD are defined in the Prometheus Operator chart. This is to resolve the potential circular dependency arising from Argo CD being rsponsible for the deployment of the Prometheus Operator chart that defines ServiceMonitors.

Examples of things to experiment with:

- understanding how metrics labels and alert labels are used by Prometheus and Alertmanager, respectively
- add and remove labels from exported metrics
- creating new receivers (e.g. Slack)
- understand and create routing trees using label matching to route alerts
- adding exporters to scrape metrics from new services
- adding new alerting rules
- adding new Grafana dashboards
- adding new Grafana data sources

## Testing
If nginx-ingress is running, configuration changes can be verified from the Prometheus/Grafana/Alertmanager UIs on one's local machine (the Grafana username/password is admin/password).
```
http://localhost:80/prometheus
http://localhost:80/grafana
http://localhost:80/alertmanager
```
Similarly, exporters and rules can be viewed in the Prometheus UI, dashboards in the Grafana UI, and triggered alerts in the Alertmanager UI.

To test routing rules, which can be confusing, https://prometheus.io/webtools/alerting/routing-tree-editor/ is a good resource. Proper downstream handling of alerts can be tested in an ad hoc manner, as opposed to waiting for a real alert to fire, by sending test alerts to Alertmanager using curl. Alerts tagged "severity": "critical" are currently routed to mock-server, which logs their JSON payload for observability (see mock-server for how to view the logs).

## Commands
```
Apply/update Prometheus Operator:
make prometheus_apply

Delete Prometheus Operator:
make prometheus_delete

Test rules:
make prometheus_test_rules

Send test alert to Alertmanager:
curl -H "Content-Type: application/json" -d '[{"labels":{"alertname":"TestAlert","severity":"critical"}}]' localhost:80/alertmanager/api/v1/alerts
```
