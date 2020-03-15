# Prometheus Operator


## Testing
If nginx-ingress is running, configuration changes can be verified from the Prometheus/Grafana/Alertmanager UIs.
```
localhost/prometheus
localhost/grafana
localhost/alertmanager
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
