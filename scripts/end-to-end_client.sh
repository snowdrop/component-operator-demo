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
SLEEP_TIME=10s
TIME=$(date +"%Y-%m-%d_%H-%M")
REPORT_FILE="result_${TIME}.txt"
EXPECTED_RESPONSE='{"status":"UP"}'
INGRESS_RESOURCES=$(kubectl get ing 2>&1)

function deleteResources() {
  result=$(kubectl api-resources --verbs=list --namespaced -o name)
  for i in $result[@]
  do
    kubectl delete $i --ignore-not-found=true --all -n $1
  done
}

function listAllK8sResources() {
  result=$(kubectl api-resources --verbs=list --namespaced -o name)
  for i in $result[@]
  do
    kubectl get $i --ignore-not-found=true -n $1
  done
}

function printTitle {
  r=$(typeset i=${#1} c="=" s="" ; while ((i)) ; do ((i=i-1)) ; s="$s$c" ; done ; echo  "$s" ;)
  printf "$r\n$1\n$r\n"
}

function createPostgresqlCapability() {
cat <<EOF | kubectl apply -n ${NS} -f -
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
EOF
}
function createFruitBackend() {
cat <<EOF | kubectl apply -n ${NS} -f -
apiVersion: "v1"
kind: "List"
items:
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
}
function createFruitClient() {
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
    kind: "Env"
    componentName: "fruit-client-sb"
    envs:
    - name: "ENDPOINT_BACKEND"
      value: "http://fruit-backend-sb:8080/api/fruits"
EOF
}

function createAll() {
  createPostgresqlCapability
  createFruitBackend
  createFruitClient
}

printTitle "Creating the namespace"
kubectl create ns ${NS}

printTitle "Deploy the component, link, ..."
#createPostgresqlCapability
#createFruitClient
#createFruitBackend
createAll

echo "Sleep ${SLEEP_TIME}"
sleep ${SLEEP_TIME}

#printTitle "List all resources"
#listAllK8sResources $NS

#printTitle "Delete the resources components, links and capabilities"
#kubectl delete components,links --all -n ${NS}
# echo "Sleep ${SLEEP_TIME}"
# sleep ${SLEEP_TIME}

# printTitle  "Delete pending resources using ApiServices registered"
# deleteResources $NS

#printTitle  "Delete namespace $NS"
#kubectl delete ns $NS