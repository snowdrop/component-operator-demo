# Spring Boot Demo using Component's CRD

  * [Introduction](#introduction)
  * [Setup](#setup)
     * [Hetzner remote's cluster](#hetzner-remotes-cluster)
     * [Local cluster using MiniShift](#local-cluster-using-minishift)
  * [Demo's time](#demos-time)
     * [Install the project](#install-the-project)
     * [Build code](#build-code)
     * [Install the components](#install-the-components)
     * [Create the database's service usign the Catalog](#create-the-databases-service-usign-the-catalog)
     * [Link the components](#link-the-components)
     * [Push the code and start the Spring Boot application](#push-the-code-and-start-the-spring-boot-application)
     * [Use ap4k and yaml files generated](#use-ap4k-and-yaml-files-generated)
     * [Check if the Component Client is replying](#check-if-the-component-client-is-replying)
  * [Cleanup](#cleanup)
     * [Demo components](#demo-components)
     * [Operator and CRD resources](#operator-and-crd-resources)


## Introduction

The purpose of this demo is to showcase how you can use `Component CRD` and a Kubernetes `operator` deployed on OpenShift to help you to install your Microservices Spring Boot 
application, instantiate a database using a Kubernetes Service Catalog and inject the required information to the different Microservices to let a Spring Boot application to access/consume a service (http endpoint, database, ...).

The demo's project consists, as depicted within the following diagram, of two Spring Boot applications and a PostgreSQL Database.

![Composition](component-operator-demo2.png)

The application to be deployed can be described using a Fluent DSL syntax as :

`(from:componentA).(to:componentB).(to:serviceA)`

where the `ComponentA` and `ComponentB` correspond respectively to a Spring Boot application `fruit-client-sb` and `fruit-backend-sb`.

The relation `from -> to` indicates that we will `reference` the `ComponentA` 
with the `ComponentB` using a `Link`.

The `link`'s purpose is to inject as `Env var(s)` the information required to by example configure the `HTTP client` of the `ComponentA` to access the 
`ComponentB` which exposes the logic of the backend's system as CRUD REST operations.
To let the `ComponentB` to access the database, we will also setup a link in oder to pass from the `Secret` of the service instance created from a K8s catalog
the parameters which are needed to configure the Spring Boot Datasource's bean.

The deployment or installation of the application in a namespace will consist in to create the resources on the platform using some `Component` yaml resource files defined according to the 
[Component API spec](https://github.com/snowdrop/component-operator/blob/master/pkg/apis/component/v1alpha1/component_types.go#L11).
When they will be created, then the `Component operator` which is a Kubernetes [controller](https://goo.gl/D8iE2K) will execute different operations to create : 
- For the `component-runtime` a development's pod running a `supervisord's daemon` able to start/stop the application [**[1]**](https://github.com/snowdrop/component-operator/blob/master/pkg/pipeline/innerloop/install.go#L56) and where we can push the `uber jar` file compiled locally, 
- A Service using the OpenShift Automation Broker and the Kubernetes Service Catalog [**[2]**](https://github.com/snowdrop/component-operator/blob/master/pkg/pipeline/servicecatalog/install.go),
- `EnvVar` section for the development's pod [**[3]**](https://github.com/snowdrop/component-operator/blob/master/pkg/pipeline/link/link.go#L56).

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

- Login to MiniShift using `admin`'s user
```bash
oc login https://$(minishift ip):8443 -u admin -p admin
```
- Deploy the resources within the namespace `component-operator` 

```bash
oc new-project component-operator
oc create -f resources/sa.yaml
oc create -f resources/cluster-rbac.yaml
oc create -f resources/user-rbac.yaml
oc create -f resources/crd.yaml
oc create -f resources/operator.yaml
```

## Demo's time

### Install the project

- Login to the OpenShift's cluster using your favorite user
```bash
oc login https://ip_address_or_hostname_fqdn>:8443 -u <user> -p <password
```

- Git clone the project locally to play with a Spring Boot composite application
```bash
git clone https://github.com/snowdrop/component-operator-demo.git && cd component-operator-demo
```

- Create a new project `my-spring-app`
```bash
oc new-project my-spring-app
```

### Build code

- Build the `Client` and the `Backend` using `mvn tool` to generate their respective  Spring Boot uber jar file
```bash
cd fruit-client
mvn package
cd ..
cd fruit-backend-sb
mvn package
cd ..
``` 

### Install the components

- Deploy for each microservice, their Component CRs on the cluster and wait till they will be processed by the controller 
  to create the corresponding kubernetes resources such as DeploymentConfig, Pod, Service, Route, ...
```bash
oc apply -f fruit-backend-sb/component.yml
oc apply -f fruit-client-sb/component.yml
```  

- Verify that we have 2 components installed
```bash
oc get components
NAME            RUNTIME       VERSION   SERVICE   TYPE      CONSUMED BY   AGE
fruit-backend-sb   spring-boot   1.5.16                                      34s
fruit-client    spring-boot   1.5.16                                      32s
```

### Create the database's service usign the Catalog

- Create the `PostgreSQL database` using the `db-service.yml` Component CR
```bash
oc apply -f service/database.yml
```

**WARNING** As this process is performed asynchrounously and is managed by the Kubernetes Service Catalog controller in combination with the Service Broker, then this process can take time !

**Remark** Use the following command to check the status of the instance which, at the end of the installation process, should be equal to `ready`
```bash
oc get serviceinstance/postgresql-db
NAME            CLASS                                   PLAN      STATUS    AGE
postgresql-db   ClusterServiceClass/dh-postgresql-apb   dev       Ready     3m
```

- Control as we did before that we have 3 components installed: 2 Spring Boot runtimes and 1 service
```bash
oc get components
NAME             RUNTIME       VERSION   SERVICE         TYPE      CONSUMED BY   AGE
fruit-backend-sb    spring-boot   1.5.16                                            2m
fruit-client     spring-boot   1.5.16                                            2m
fruit-database                           postgresql-db                           6s
```

### Link the components

- Inject as ENV variables the parameters of the database to let Spring Boot to create a Datasource's bean to connect to the database using the
  secret created 
```bash
oc apply -f fruit-backend-sb/env-secret-service.yml
```  

- Inject the endpoint's address of the `fruit backend` application as an ENV Var. This ENV Var will be used as parameter by the Spring Boot application
  to configure the HTTP client to access the backend
```bash
oc apply -f fruit-client-sb/env-backend-endpoint.yml
``` 

### Push the code and start the Spring Boot application

- As we have finished to compose our application `from Spring Boot Http Client` -> to `Spring Boot REST Backend` -> to `PostgreSQL` database, we will 
  now copy the uber jar files, and next start the `client`, `backend` Spring Boot applications. Execute the following commands : 
```bash
./push_start.sh fruit-client sb
./push_start.sh fruit-backend sb
```  

### Use ap4k and yaml files generated

- Edit the pom.xml file of the `fruit-client-sb` and `fruit-backend-sb` maven modules and add the `ap4k` gavs (responsible to scan the annotated class and to generate the yaml resource files)
```xml
<!-- To generate CRD -->
<dependency>
    <groupId>io.ap4k</groupId>
    <artifactId>ap4k-core</artifactId>
    <version>1.0-SNAPSHOT</version>
</dependency>
<dependency>
    <groupId>io.ap4k</groupId>
    <artifactId>component-annotations</artifactId>
    <version>1.0-SNAPSHOT</version>
</dependency>
<!-- Only needed for the backend component -->
<dependency>
    <groupId>io.ap4k</groupId>
    <artifactId>servicecatalog-annotations</artifactId>
    <version>1.0-SNAPSHOT</version>    
</dependency>
<dependency>
    <groupId>io.ap4k</groupId>
    <artifactId>ap4k-spring-boot</artifactId>
    <version>1.0-SNAPSHOT</version>    
</dependency>
```

- Edit the `Application` class to specify the Component's definition
  **client**
  ```java
  @CompositeApplication(
          name = "fruit-client-sb",
          exposeService = true,
          links = @Link(
                    name = "Env var to be injected within the target component -> fruit-backend",
                    targetcomponentname = "fruit-client-sb",
                    kind = "Env",
                    ref = "",
                    envVars = @Env(
                            name  = "OPENSHIFT_ENDPOINT_BACKEND",
                            value = "http://fruit-backend-sb:8080/api/fruits"
                    )
  ))
  ```
  **Backend**
  ```java
  @CompositeApplication(
          name = "fruit-backend-sb",
          exposeService = true,
          envVars = @Env(
                  name = "SPRING_PROFILES_ACTIVE",
                  value = "openshift-catalog"),
          links = @Link(
                  name = "Secret to be injected as EnvVar using Service's secret",
                  targetcomponentname = "fruit-backend-sb",
                  kind = "Secret",
                  ref = "postgresql-db"))
  @ServiceCatalog(
     instances = @ServiceCatalogInstance(
          name = "postgresql-db",
          serviceClass = "dh-postgresql-apb",
          servicePlan = "dev",
          bindingSecret = "postgresql-db",
          parameters = {
                  @Parameter(key = "postgresql_user", value = "luke"),
                  @Parameter(key = "postgresql_password", value = "secret"),
                  @Parameter(key = "postgresql_database", value = "my_data"),
                  @Parameter(key = "postgresql_version", value = "9.6")
          }
     )
  ) 
  ```  
- Compile the modules at the root of the project
```bash
mvn clean install
```

- Deploy the generated `component.yaml` resource files
```bash
oc apply -f fruit-client-sb/target/classes/META-INF/ap4k/component.yml
oc apply -f fruit-backend-sb/target/classes/META-INF/ap4k/component.yml
``` 

- Push the code and launch the java application
```bash
./push_start.sh fruit-client sb
./push_start.sh fruit-backend sb
```

### Check if the Component Client is replying

- Call the HTTP Endpoint exposed by the `Spring Boot Fruit Client` in order to fetch data from the database
```bash
route_address=$(oc get route/fruit-client-sb -o jsonpath='{.spec.host}' )
curl http://$route_address/api/client
or 

using httpie client
http http://$route_address/api/client
http http://$route_address/api/client/1
http http://$route_address/api/client/2
http http://$route_address/api/client/3
``` 

### Nodejs deployment

- Build node project locally
```bash
cd fruit-client-nodejs
nvm use v10.1.0
npm audit fix
npm install -s --only=production
```

- Run locally
```bash
export OPENSHIFT_ENDPOINT_BACKEND=http://fruit-backend-sb.my-spring-app.195.201.87.126.nip.io/api/fruits
npm run -d start      
```

- Deploy the node's component and link it to the Spring Boot fruit backend
```bash
oc apply -f fruit-client-nodejs/component.yml
oc apply -f fruit-client-nodejs/env-backend-endpoint.yml
```

- Push the code and start the nodejs application
```bash
./push_start.sh fruit-client nodejs
```

- Test it locally or remotely
```bash
# locally
http :8080/api/client
http :8080/api/client/1 

#Remotely
route_address=$(oc get route/fruit-client-nodejs -o jsonpath='{.spec.host}' )
curl http://$route_address/api/client
or 

using httpie client
http http://$route_address/api/client
http http://$route_address/api/client/1
http http://$route_address/api/client/2
http http://$route_address/api/client/3
```

## Cleanup

### Demo components

```bash
oc delete cp/fruit-backend-sb
oc delete cp/fruit-database
oc delete cp/fruit-database-config

oc delete cp/fruit-client
oc delete cp/fruit-endpoint
```

### Operator and CRD resources

```bash
oc delete -f resources/sa.yaml -n component-operator
oc delete -f resources/cluster-rbac.yaml
oc delete -f resources/crd.yaml 
oc delete -f resources/operator.yaml -n component-operator
```
  
