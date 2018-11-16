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

- Git clone the project locally to play with a Spring Boot composite application
```bash
git clone https://github.com/snowdrop/component-operator-demo.git && cd component-operator-demo
```

- Create a new project `my-spring-app`
```bash
oc new-project my-spring-app
```

- Build the `Client` and the `Backend` using `mvn tool` to generate their respective  Spring Boot uber jar file
```bash
cd fruit-client
mvn package
cd ..
cd fruit-backend
mvn package
cd ..
``` 

- Deploy for each microservice, their Component CRs on the cluster and wait till they will be processed by controller 
  to generate or create the corresponding kubernetes resources such as DeploymentConfig, Pod, Service, Route, ...
```bash
oc apply -f fruit-backend/component.yml
oc apply -f fruit-client/component.yml
```  

- Verify that we have 2 components installed
```bash
oc get cpoc get cp
NAME            RUNTIME       VERSION   SERVICE   TYPE      CONSUMED BY   AGE
fruit-backend   spring-boot   1.5.16                                      34s
fruit-client    spring-boot   1.5.16                                      32s
```

- Create the PostgreSQL database using the `db-service.yml` Component CR
```bash
oc apply -f fruit-backend/db-service.yml
```

- Control as we did before that we have 3 components installed: 2 runtimes and 1 service
```bash
oc get cp
NAME             RUNTIME       VERSION   SERVICE         TYPE      CONSUMED BY   AGE
fruit-backend    spring-boot   1.5.16                                            2m
fruit-client     spring-boot   1.5.16                                            2m
fruit-database                           postgresql-db                           6s
```