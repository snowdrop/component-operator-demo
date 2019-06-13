#!/usr/bin/env bash

#
# End to end scenario to be executed on minikube or k8s cluster
#
CLUSTER_IP=${1:-$(minikube ip)}
SLEEP_TIME=60s
TIME=$(date +"%Y-%m-%d_%H-%M")
REPORT_FILE="result_${TIME}.txt"

INGRESS_RESOURCES=$(kubectl get ing 2>&1)

kubectl create ns demo
echo "##################################################################"
echo "Deleting the resources components, links and capabilities"
echo "##################################################################"
kubectl delete components,link,capabilities --all -n demo
echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

echo "##################################################################"
echo "Deploy the component for the fruit-backend, link and capability"
echo "##################################################################"
kubectl apply -f fruit-backend-sb/target/classes/META-INF/ap4k/component.yml -n demo
echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

echo "##################################################################"
echo "Deploy the component for the fruit-client, link"
echo "##################################################################"
kubectl apply -f fruit-client-sb/target/classes/META-INF/ap4k/component.yml -n demo
echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

printf "Resources status\n=================\n" > ${REPORT_FILE}
if [ "$INGRESS_RESOURCES" == "No resources found." ]; then
  kubectl get all,pvc,routes,serviceinstance,servicebinding,secrets -n demo >> ${REPORT_FILE}
else
  kubectl get all,pvc,ing,serviceinstance,servicebinding,secrets -n demo >> ${REPORT_FILE}
fi

printf "\nENV injected to the fruit backend\n=====================\n" >> ${REPORT_FILE}
kubectl exec -n demo $(kubectl get pod -n demo -lapp=fruit-backend-sb | grep "Running" | awk '{print $1}') env | grep DB >> ${REPORT_FILE}
printf "\n" >> ${REPORT_FILE}

printf "\nENV var defined for the fruit client\n=====================\n" >> ${REPORT_FILE}
kubectl describe -n demo pod/$(kubectl get pod -n demo -lapp=fruit-client-sb | grep "Running" | awk '{print $1}') >> ${REPORT_FILE}
printf "\n" >> ${REPORT_FILE}

echo "##################################################################"
echo "Push fruit and backend"
echo "##################################################################"
./scripts/k8s_push_start.sh fruit-backend sb demo
./scripts/k8s_push_start.sh fruit-client sb demo

echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

echo "##################################################################"
echo "Curl Fruit service"
echo "##################################################################"
printf "\nCurl Fruit Endpoint service\n=====================\n"  >> ${REPORT_FILE}

if [ "$INGRESS_RESOURCES" == "No resources found." ]; then
    echo "No ingress resources found. We run on OpenShift"
    FRONTEND_ROUTE_URL=$(kubectl get route/fruit-client-sb -o jsonpath='{.spec.host}' -n demo)
    curl http://$FRONTEND_ROUTE_URL/api/client >> ${REPORT_FILE}
else
    FRONTEND_ROUTE_URL=fruit-client-sb.$CLUSTER_IP.nip.io
    curl -H "Host: fruit-client-sb" ${FRONTEND_ROUTE_URL}/api/client >> ${REPORT_FILE}
fi