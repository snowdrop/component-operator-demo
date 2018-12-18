#!/usr/bin/env bash

component=$1
cmd=$2
namespace=${3:-my-spring-app}

pod_name=$(kubectl get pod -lapp=${component} -o name -n ${namespace})
pod_id=${pod_name#"pod/"}

kubectl exec $pod_id -n ${namespace} ${cmd}

