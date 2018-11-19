#!/usr/bin/env bash

component=$1

pod_name=$(oc get pod -lapp=${component} -o name)
name=$(cut -d'/' -f2 <<<$pod_name)
oc cp ${component}/target/${component}-0.0.1-SNAPSHOT.jar $name:/deployments/app.jar

echo "## jar file ${component}/target/${component}-0.0.1-SNAPSHOT.jar pushed ..."

oc rsh $pod_name /var/lib/supervisord/bin/supervisord ctl stop run-java
oc rsh $pod_name /var/lib/supervisord/bin/supervisord ctl start run-java

echo "## component ${component} (re)started"