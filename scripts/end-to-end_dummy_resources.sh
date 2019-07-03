#!/usr/bin/env bash

#
# Prerequisite : install tool jq
# This script assumes that KubeDB & Component operators are installed
#
# End to end scenario to be executed on minikube, minishift or k8s cluster
# Example: ./scripts/end-to-end.sh CLUSTER_IP
# where CLUSTER_IP represents the external IP address exposed top of the VM
#
CLUSTER_IP=${1:-$(minikube ip)}
NS=${2:-test1}
SLEEP_TIME=60s
TIME=$(date +"%Y-%m-%d_%H-%M")
REPORT_FILE="result_${TIME}.txt"

INGRESS_RESOURCES=$(kubectl get ing 2>&1)

function printTitle {
  r=$(typeset i=${#1} c="=" s="" ; while ((i)) ; do ((i=i-1)) ; s="$s$c" ; done ; echo  "$s" ;)
  printf "$r\n$1\n$r\n"
}

kubectl create ns ${NS}
printTitle "Delete the resources components, links and capabilities"
kubectl delete components,links,capabilities --all -n ${NS}
echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

printTitle "Deploy the component for the fruit-backend, link and capability"
cat <<EOF | kubectl apply -n ${NS} -f -
---
apiVersion: "v1"
kind: "List"
items:
- apiVersion: devexp.runtime.redhat.com/v1alpha2
  kind: Capability
  metadata:
    name: postgres-db
  spec:
    category: database
    kind: postgres
    version: "10"
    parameters:
    - name: DB_USER
      value: admin
    - name: DB_PASSWORD
      value: admin
- apiVersion: devexp.runtime.redhat.com/v1alpha2
  kind: Component
  metadata:
    name: fruit-backend-sb
    labels:
      app: fruit-backend-sb
  spec:
    deploymentMode: dev
    buildConfig:
      url: https://github.com/snowdrop/component-operator-demo.git
      ref: master
      moduleDirName: fruit-backend-sb
    runtime: spring-boot
    version: 2.1.3
    envs:
    - name: SPRING_PROFILES_ACTIVE
      value: postgresql-kubedb
- apiVersion: "devexp.runtime.redhat.com/v1alpha2"
  kind: "Link"
  metadata:
    name: "link-to-postgres-db"
  spec:
    componentName: "fruit-backend-sb"
    kind: "Secret"
    ref: "postgres-db-config"
EOF
echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

printTitle "Deploy the component for the fruit-client, link"
cat <<EOF | kubectl apply -n ${NS} -f -
---
apiVersion: "v1"
kind: "List"
items:
- apiVersion: "devexp.runtime.redhat.com/v1alpha2"
  kind: "Component"
  metadata:
    labels:
      app: "fruit-client-sb"
      version: "0.0.1-SNAPSHOT"
    name: "fruit-client-sb"
  spec:
    deploymentMode: "dev"
    runtime: "spring-boot"
    version: "2.1.3.RELEASE"
    exposeService: true
- apiVersion: "devexp.runtime.redhat.com/v1alpha2"
  kind: "Link"
  metadata:
    name: "link-to-fruit-backend"
  spec:
    name: "link-to-fruit-backend"
    kind: "Env"
    componentName: "fruit-client-sb"
    ref: ""
    envs:
    - name: "ENDPOINT_BACKEND"
      value: "http://fruit-backend-sb:8080/api/fruits"
EOF
echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

printTitle "Report status : ${TIME}" > ${REPORT_FILE}

printTitle "1. Status of the resources created using the CRDs : Component, Link or Capability" >> ${REPORT_FILE}
if [ "$INGRESS_RESOURCES" == "No resources found." ]; then
  for i in components links capabilities pods deployments deploymentconfigs services routes pvc postgreses secret/postgres-db-config
  do
    printTitle "$(echo $i | tr a-z A-Z)" >> ${REPORT_FILE}
    kubectl get $i -n ${NS} >> ${REPORT_FILE}
    printf "\n" >> ${REPORT_FILE}
  done
else
  for i in components links capabilities pods deployments servicces ingresses pvc postgreses secret/postgres-db-config
  do
    printTitle "$(echo $i | tr a-z A-Z)" >> ${REPORT_FILE}
    kubectl get $i -n ${NS} >> ${REPORT_FILE}
    printf "\n" >> ${REPORT_FILE}
  done
fi

printTitle "2. ENV injected to the fruit backend component" >> ${REPORT_FILE}
kubectl exec -n ${NS} $(kubectl get pod -n ${NS} -lapp=fruit-backend-sb | grep "Running" | awk '{print $1}') env | grep DB >> ${REPORT_FILE}
printf "\n" >> ${REPORT_FILE}

printTitle "3. ENV var defined for the fruit client component" >> ${REPORT_FILE}
# kubectl describe -n ${NS} pod/$(kubectl get pod -n ${NS} -lapp=fruit-client-sb | grep "Running" | awk '{print $1}') >> ${REPORT_FILE}
# See jsonpath examples : https://kubernetes.io/docs/reference/kubectl/cheatsheet/
for item in $(kubectl get pod -n ${NS} -lapp=fruit-client-sb --output=name); do printf "Envs for %s\n" "$item" | grep --color -E '[^/]+$' && kubectl get "$item" --output=json | jq -r -S '.spec.containers[0].env[] | " \(.name)=\(.value)"' 2>/dev/null; printf "\n"; done >> ${REPORT_FILE}
printf "\n" >> ${REPORT_FILE}

printTitle "Push fruit client and backend"
./scripts/k8s_push_start.sh fruit-backend sb ${NS}
./scripts/k8s_push_start.sh fruit-client sb ${NS}

echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

printTitle "Curl Fruit service"
printTitle "4. Curl Fruit Endpoint service"  >> ${REPORT_FILE}

if [ "$INGRESS_RESOURCES" == "No resources found." ]; then
    echo "No ingress resources found. We run on OpenShift" >> ${REPORT_FILE}
    FRONTEND_ROUTE_URL=$(kubectl get route/fruit-client-sb -o jsonpath='{.spec.host}' -n ${NS})
    curl http://$FRONTEND_ROUTE_URL/api/client >> ${REPORT_FILE}
else
    FRONTEND_ROUTE_URL=fruit-client-sb.$CLUSTER_IP.nip.io
    curl -H "Host: fruit-client-sb" ${FRONTEND_ROUTE_URL}/api/client >> ${REPORT_FILE}
fi

# kubectl delete ns ${NS}