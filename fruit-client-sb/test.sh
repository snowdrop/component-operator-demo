supervisordBin="/var/lib/supervisord/bin/supervisord"
supervisordCtl="ctl"
runCmdName="run-java"
pod_name=$(oc get pod -lapp=fruit-client -o name)
name=$(cut -d'/' -f2 <<<$pod_name)

echo "Pod name is : $name"
echo "oc cp target/fruit-client-0.0.1-SNAPSHOT.jar $name:/deployments/app.jar"
oc cp target/fruit-client-0.0.1-SNAPSHOT.jar $name:/deployments/app.jar

echo "oc rsh $pod_name $supervisordBin $supervisordCtl stop $runCmdName"
oc rsh $pod_name $supervisordBin $supervisordCtl stop $runCmdName
oc rsh $pod_name $supervisordBin $supervisordCtl start $runCmdName
