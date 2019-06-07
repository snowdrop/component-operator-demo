#!/usr/bin/env bash

set -x

component=$1
runtime=$2
project=$component-$runtime
namespace=${3:-my-spring-app}

pod_name=$(kubectl get pod -lapp=${project} -o name -n ${namespace}) | grep "Running"
pod_id=${pod_name#"pod/"}
name=$(cut -d'/' -f2 <<<$pod_name)

echo "## $runtime files ${project} pushed ..."

if [ $runtime = "nodejs" ]; then
  cmd="run-node"
  kubectl rsync $project/ $name:/opt/app-root/src/ --no-perms=true -n ${namespace}
else
  cmd="run-java"
  kubectl cp ${project}/target/${project}-0.0.1-SNAPSHOT.jar $name:/deployments/app.jar -n ${namespace}
fi

kubectl exec $pod_id -n ${namespace} /var/lib/supervisord/bin/supervisord ctl stop $cmd
kubectl exec $pod_id -n ${namespace} /var/lib/supervisord/bin/supervisord ctl start $cmd

echo "## component ${component} (re)started"