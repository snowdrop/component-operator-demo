#!/usr/bin/env bash

component=$1
project=$component-sb

pod_name=$(oc get pod -lapp=${component} -o name)
name=$(cut -d'/' -f2 <<<$pod_name)
oc cp ${project}/target/${component}-0.0.1-SNAPSHOT.jar $name:/deployments/app.jar
# TODO : use odo rsync
# oc rsync $project/ $name:/opt/app-root/src/ --no-perms=true

echo "## jar file ${project}/target/${component}-0.0.1-SNAPSHOT.jar pushed ..."

oc rsh $pod_name /var/lib/supervisord/bin/supervisord ctl stop run-java
oc rsh $pod_name /var/lib/supervisord/bin/supervisord ctl start run-java

echo "## component ${component} (re)started"