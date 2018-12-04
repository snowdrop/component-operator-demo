

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
