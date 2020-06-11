# Conftest
Conftest is a program that runs Rego checks against structured configurations (e.g. Kubernetes manifests) to surface potential issues (e.g. use of deprecated Kubernetes APIs).

Current checks include:

- deprek8 - for catching use of deprecated Kubernetes APIs; from https://github.com/naquada/deprek8/blob/master/policy/deprek8.rego (remember to update this to cover new Kubernetes versions)

## Commands
```
Check all applications for use of deprecated Kubernetes APIs:
make conftest_deprek8
```
