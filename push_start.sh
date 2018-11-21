#!/usr/bin/env bash

component=$1
runtime=$2
project=$component-$runtime

pod_name=$(oc get pod -lapp=${project} -o name)
name=$(cut -d'/' -f2 <<<$pod_name)

echo "## $runtime files ${project} pushed ..."

if [ $runtime = "nodejs" ]; then
  cmd="run-node"
  oc rsync $project/ $name:/opt/app-root/src/ --no-perms=true
else
  cmd="run-java"
  oc cp ${project}/target/${project}-0.0.1-SNAPSHOT.jar $name:/deployments/app.jar
fi

oc rsh $pod_name /var/lib/supervisord/bin/supervisord ctl stop $cmd
oc rsh $pod_name /var/lib/supervisord/bin/supervisord ctl start $cmd

echo "## component ${component} (re)started"