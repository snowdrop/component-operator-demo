## Dummy application 

- Log on to OpenShift 3.11 with a user having cluster-admin role
- Execute the following requests

```bash
oc delete crd/runtimes.application.k8s.io
oc delete crd/services.application.k8s.io
oc delete crd/links.application.k8s.io

oc apply -f resources/application/crd-link.yml
oc apply -f resources/application/crd-runtime.yml
oc apply -f resources/application/crd-service.yml

oc apply -f resources/application/runtime.yml
oc apply -f resources/application/service.yml
oc apply -f resources/application/link-a.yml

oc get application
```

- You will get
```
oc get application
NAME            TYPE
postgresql-db   Service

NAME                TYPE
fruit-endpoint-sb   Link

NAME              TYPE      RUNTIME
fruit-client-sb   Runtime   spring-boot
```

**Remark**: We can display the different types as separate entries but we can't show them as one unified table such as this one

```
NAME            RUNTIME       AGE
postgresql-db                 4s
fruit-endpoint-sb             3s
fruit-client-sb   spring-boot
```

