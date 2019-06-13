#!/usr/bin/env bash

#
# Prerequisite : install tool jq
#
# End to end scenario to be executed on minikube, minishift or k8s cluster
# Example: ./scripts/end-to-end.sh CLUSTER_IP
# where CLUSTER_IP represents the external IP address exposed top of the VM
#
CLUSTER_IP=${1:-$(minikube ip)}
SLEEP_TIME=60s
TIME=$(date +"%Y-%m-%d_%H-%M")
REPORT_FILE="result_${TIME}.txt"

INGRESS_RESOURCES=$(kubectl get ing 2>&1)

function printTitle {
  r=$(typeset i=${#1} c="=" s="" ; while ((i)) ; do ((i=i-1)) ; s="$s$c" ; done ; echo  "$s" ;)
  printf "$r\n$1\n$r\n"
}

kubectl create ns demo
printTitle "Deleting the resources components, links and capabilities"
kubectl delete components,link,capabilities --all -n demo
echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

printTitle "Deploy the component for the fruit-backend, link and capability"
kubectl apply -f fruit-backend-sb/target/classes/META-INF/ap4k/component.yml -n demo
echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

printTitle "Deploy the component for the fruit-client, link"
kubectl apply -f fruit-client-sb/target/classes/META-INF/ap4k/component.yml -n demo
echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

printTitle "Report status : ${TIME}" > ${REPORT_FILE}

printTitle "Status of the resources created using the CRDs : Component, Link or Capability" >> ${REPORT_FILE}
if [ "$INGRESS_RESOURCES" == "No resources found." ]; then
  for i in components links capabilities pods deployments deploymentconfigs services routes pvc serviceinstances servicebindings secret/postgresql-db
  do
    printTitle "$(echo $i | tr a-z A-Z)" >> ${REPORT_FILE}
    kubectl get $i -n demo >> ${REPORT_FILE}
    printf "\n" >> ${REPORT_FILE}
  done
else
  for i in components links capabilities pods deployments servicces ingresses pvc serviceinstances servicebindings secret/postgresql-db
  do
    printTitle "$(echo $i | tr a-z A-Z)" >> ${REPORT_FILE}
    kubectl get $i -n demo >> ${REPORT_FILE}
    printf "\n" >> ${REPORT_FILE}
  done
fi

printTitle "ENV injected to the fruit backend component" >> ${REPORT_FILE}
kubectl exec -n demo $(kubectl get pod -n demo -lapp=fruit-backend-sb | grep "Running" | awk '{print $1}') env | grep DB >> ${REPORT_FILE}
printf "\n" >> ${REPORT_FILE}

printTitle "ENV var defined for the fruit client component" >> ${REPORT_FILE}
# kubectl describe -n demo pod/$(kubectl get pod -n demo -lapp=fruit-client-sb | grep "Running" | awk '{print $1}') >> ${REPORT_FILE}
# See jsonpath examples : https://kubernetes.io/docs/reference/kubectl/cheatsheet/
for item in $(kubectl get pod -n demo -lapp=fruit-client-sb --output=name); do printf "Envs for %s\n" "$item" | grep --color -E '[^/]+$' && kubectl get "$item" --output=json | jq -r -S '.spec.containers[0].env[] | " \(.name)=\(.value)"' 2>/dev/null; printf "\n"; done >> ${REPORT_FILE}
printf "\n" >> ${REPORT_FILE}

printTitle "Push fruit and backend"
./scripts/k8s_push_start.sh fruit-backend sb demo
./scripts/k8s_push_start.sh fruit-client sb demo

echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

printTitle "Curl Fruit service"
printTitle "Curl Fruit Endpoint service"  >> ${REPORT_FILE}

if [ "$INGRESS_RESOURCES" == "No resources found." ]; then
    echo "No ingress resources found. We run on OpenShift" >> ${REPORT_FILE}
    FRONTEND_ROUTE_URL=$(kubectl get route/fruit-client-sb -o jsonpath='{.spec.host}' -n demo)
    curl http://$FRONTEND_ROUTE_URL/api/client >> ${REPORT_FILE}
else
    FRONTEND_ROUTE_URL=fruit-client-sb.$CLUSTER_IP.nip.io
    curl -H "Host: fruit-client-sb" ${FRONTEND_ROUTE_URL}/api/client >> ${REPORT_FILE}
fi