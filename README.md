# Spring Boot Demo

 * [Introduction](#introduction)
 * [Setup](#setup)
    * [Hetzner remote's cluster](#hetzner-remotes-cluster)
    * [Local cluster using MiniShift](#local-cluster-using-minishift)
    * [Clean up](#clean-up)
 * [Demo's time](#demos-time)


## Introduction

## Setup

### Hetzner remote's cluster
```bash
oc login https://195.201.87.126:8443 --token=TOKEN_PROVIDED_BY_SNOWDROP_TEAM
oc project <user_project>
```

### Local cluster using MiniShift

- Minishift (>= v1.26.1) with Service Catalog feature enabled
- Launch Minishift VM

```bash
# if you don't have a minishift VM, start as follows
minishift addons enable xpaas
minishift addons enable admin-user
minishift start
minishift openshift component add service-catalog
minishift openshift component add automation-service-broker
```

- Add `Cluster Admin` role to the admin user
```bash
oc login -u system:admin
oc adm policy add-cluster-role-to-user cluster-admin admin
oc login -u admin -p admin
```

- Deploy the resources within the namespace `component-operator`

```bash
oc new-project component-operator
oc create -f resources/sa.yaml
oc create -f resources/cluster-rbac.yaml
oc create -f resources/crd.yaml
oc create -f resources/operator.yaml
```

### Clean up
```bash
oc delete -f resources/sa.yaml
oc delete -f resources/cluster-rbac.yaml
oc delete -f resources/crd.yaml
oc delete -f resources/operator.yaml
```

## Demo's time

- Git clone the demo project to play with a composite application
```bash
git clone https://github.com/snowdrop/component-operator-demo.git && cd component-operator-demo
```
