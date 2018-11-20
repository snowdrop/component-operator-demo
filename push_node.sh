#!/usr/bin/env bash

component=$1
runtime=$2
project=$component-$runtime

pod_name=$(oc get pod -lapp=${component} -o name)
name=$(cut -d'/' -f2 <<<$pod_name)
oc rsync $project/ $name:/opt/app-root/src/ --no-perms=true

echo "## nodejs files ${project} pushed ..."

oc rsh $pod_name /var/lib/supervisord/bin/supervisord ctl stop run-node
oc rsh $pod_name /var/lib/supervisord/bin/supervisord ctl start run-node

echo "## component ${component} (re)started"