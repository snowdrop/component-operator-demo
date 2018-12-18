#!/usr/bin/env bash

component=$1
runtime=$2
project=$component-$runtime

pod_name=$(kubectl get pod -lapp=${project} -o name)
name=$(cut -d'/' -f2 <<<$pod_name)

echo "## $runtime files ${project} pushed ..."

if [ $runtime = "nodejs" ]; then
  cmd="run-node"
  kubectl rsync $project/ $name:/opt/app-root/src/ --no-perms=true
else
  cmd="run-java"
  kubectl cp ${project}/target/${project}-0.0.1-SNAPSHOT.jar $name:/deployments/app.jar
fi

kubectl rsh $pod_name /var/lib/supervisord/bin/supervisord ctl stop $cmd
kubectl rsh $pod_name /var/lib/supervisord/bin/supervisord ctl start $cmd

echo "## component ${component} (re)started"