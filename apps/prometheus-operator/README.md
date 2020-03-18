# Prometheus Operator
Prometheus Operator deploys a Prometheus-based monitoring stack that includes Grafana and Alertmanager. It also includes default metrics exporters, dashboards, and rules (we've included the metrics exporters and dashboards, but disabled the default rules).

Prometheus is a popular time-series database that is used for collecting, processing, and alerting on metrics. Specifically, applications that wish to send metrics to Prometheus expose a metrics endpoint that is periodically scraped by Prometheus exporters (the exporters are configured as part of Prometheus' configuration). Prometheus then applies a set of rules (defined in a set of YAML files) to the metrics for processing and possible alerting.

In the case of alerts being triggered, they are sent to Alertmanager. Alertmanager subsequently preprocesses the alerts (e.g., additional formatting, grouping) and routes them to receivers (e.g., Slack, arbitrary webhook endpoint) based on routing rules defined in its configuration. Alertmanager keeps track of alerts it has received, allowing users to silence superfluous alerts.

Grafana is the visualization component of the Prometheus monitoring and alerting stack. It can connect to a number of data sources, Prometheus amongst them, and render graphs, charts, tables, etc. based on queries on the metrics in the data sources. These can then be saved as dashboards for continuous display or shared with others.

Prometheus Operator automates deployment of the stack by automatically providing the glue that binds the components.

Prometheus' configuration is templated out and configurable through values.yaml. Exporters are configured through ServiceMonitor objects that tie an exporter to the service it is meant to scrape. Similarly, PrometheusRule objects store rules that are imported into the Prometheus instance(s). In this project, ServiceMonitor creation is templated out and can be configured in values.yaml while PrometheusRule creation is automated based on the rules found in rules/. The base Prometheus Operator chart's default rules have been disabled, but its default exporters are enabled and can be configured in values.yaml.

Alertmanager's configuration (alertmanager/alertmanager.yaml) is rendered into a Secret object which is mounted by the Alertmanager instance(s).

Grafana's configuration can be found in values.yaml. This, along with dashboard and data source configurations, are rendered by the base Prometheus Operator chart into ConfigMap objects which are mounted by Grafana instance(s).

The cluster configuration (kind/config.yaml) changes the metrics bind address for kube-proxy and etcd from the default 127.0.0.1 to 0.0.0.0 so that their respective exporters can scrape their metrics.

The convention for this project is for apps that wish to expose metrics via endpoints to define their Service manifests in their own app but to define their ServiceMonitor manifests in the values file of the prometheus-operator app (e.g., nginx-ingress, node-problem-detector). This is because ServiceMonitor is a Custom Resource created by the prometheus-operator app and thus would otherwise impose ordering on app deployment. The metrics Services have no effect in the absence of their respective ServiceMonitor objects.

Examples of things to experiment with:

- understanding how metrics labels and alert labels are used by Prometheus and Alertmanager, respectively
- creating new receivers (e.g. Slack)
- creating a routing tree using label matching with which to route alerts
- adding exporters to scrape metrics from new services
- adding new alerting rules
- adding new Grafana dashboards
- adding new Grafana data sources

## Testing
If nginx-ingress is running, configuration changes can be verified from the Prometheus/Grafana/Alertmanager UIs on one's local machine (the Grafana username/password is admin/password).
```
localhost:80/prometheus
localhost:80/grafana
localhost:80/alertmanager
```
Similarly, exporters and rules can be viewed in the Prometheus UI, dashboards in the Grafana UI, and triggered alerts in the Alertmanager UI.

One can also send test alerts to Alertmanager using curl to test routing rules. Alerts tagged "severity": "critical" are currently routed to mock-server, which logs their JSON payload for observability (see mock-server for how to view the logs).

## Commands
```
Apply/update prometheus operator:
make prometheus_apply

Delete prometheus operator:
make prometheus_delete

Test alerting rules:
make prometheus_test_rules

Send test alert to Alertmanager:
curl -H "Content-Type: application/json" -d '[{"labels":{"alertname":"TestAlert","severity":"critical"}}]' localhost:80/alertmanager/api/v1/alerts
```
