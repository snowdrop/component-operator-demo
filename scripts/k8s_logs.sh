#!/usr/bin/env bash

component=$1
namespace=${2:-my-spring-app}

pod_name=$(kubectl get pod -lapp=${component} -o name -n ${namespace})
pod_id=${pod_name#"pod/"}

kubectl logs -n ${namespace} ${pod_id}

