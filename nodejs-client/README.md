## Install k8s resources
```bash
oc apply -f nodejs-client/.openshiftio/application.yaml 
```

## Start build

```bash
oc start-build nodejs-rest-http --from-dir=. --follow
```

## Build localy 
```bash
nvm use v10.1.0
npm install -s --only=production
npm audit fix
```

## Push
```bash
./push_node.sh nodejs-rest-http
```
