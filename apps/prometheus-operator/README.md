# Prometheus Operator


## Testing
Configuration change propagation can be validated from the Prometheus/Grafana/Alertmanager UIs (after applying NGINX Ingress).
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
