## Install k8s resources
```bash
oc apply -f nodejs-client/.openshiftio/application.yaml 
```

## Start build

```bash
oc start-build nodejs-rest-http --from-dir=. --follow
```