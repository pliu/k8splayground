# Prometheus Operator


## Testing
Configuration change propagation can be validated from the Prometheus UI (after port-forwarding).

## Commands
```
Apply/update prometheus operator:
make prometheus_apply

Delete prometheus operator:
make prometheus_delete

Port-forward Prometheus, Grafana, and Alertmanager to ports 9000, 9001, and 9002, respectively:
make .prometheus_pf

Stop port-forwarding:
make .prometheus_pf_stop

Test alerting rules:
make prometheus_test_rules
```
