# Prometheus Operator


The convention for this project is for apps that wish to expose metrics via endpoints to define their Service manifests in their own app but to define their ServiceMonitor manifests in the values file of the prometheus-operator app (e.g., nginx-ingress, node-problem-detector). This is because ServiceMonitor is a Custom Resource created by the prometheus-operator app and thus would otherwise impose ordering on app deployment. The metrics Services have no effect in the absence of their respective ServiceMonitor objects.

## Testing
If nginx-ingress is running, configuration changes can be verified from the Prometheus/Grafana/Alertmanager UIs.
```
localhost:80/prometheus
localhost:80/grafana
localhost:80/alertmanager
```

## Commands
```
Apply/update prometheus operator:
make prometheus_apply

Delete prometheus operator:
make prometheus_delete

Test alerting rules:
make prometheus_test_rules
```
