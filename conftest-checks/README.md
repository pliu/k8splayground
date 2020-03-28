# Conftest
Conftest is a program that runs Rego checks against structured configurations (e.g. k8s manifests) to surface potential issues (e.g. use of deprecated k8s APIs).

Current checks include:

- deprek8 - for catching use of deprecated k8s APIs; from https://github.com/naquada/deprek8/blob/master/policy/deprek8.rego (remember to update this to cover new k8s versions)

## Commands
```
Check all apps for use of deprecated k8s APIs:
make conftest_deprek8
```
