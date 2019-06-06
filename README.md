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
     * [Using K8s](#using-k8s)
     * [Switch from Dev to Build mode](#switch-from-dev-to-build-mode)
     * [Nodejs deployment](#nodejs-deployment)
     * [Scaffold a project](#scaffold-a-project)

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

To let the `ComponentB` to access the database, we will also setup a `link` in order to pass using the `Secret` of the service instance created the parameters which are needed to configure a Spring Boot Datasource's bean.

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
oc apply -f https://raw.githubusercontent.com/snowdrop/component-operator/master/deploy/sa.yaml
oc apply -f https://raw.githubusercontent.com/snowdrop/component-operator/master/deploy/cluster-rbac.yaml
oc apply -f https://raw.githubusercontent.com/snowdrop/component-operator/master/deploy/user-rbac.yaml
oc apply -f https://raw.githubusercontent.com/snowdrop/component-operator/master/deploy/crds/capability_v1alpha2.yaml
oc apply -f https://raw.githubusercontent.com/snowdrop/component-operator/master/deploy/crds/component_v1alpha2.yaml
oc apply -f https://raw.githubusercontent.com/snowdrop/component-operator/master/deploy/crds/link_v1alpha2.yaml
oc apply -f https://raw.githubusercontent.com/snowdrop/component-operator/master/deploy/operator.yaml
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
./scripts/push_start.sh fruit-client sb
./scripts/push_start.sh fruit-backend sb
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

- Edit the `Application` class to specify the Component's definition, service or relations (= links).

  The `@CompositeApplication` is used by the `ap4k` lib to generate a `Component CRD` resource, containing
  the definition of the runtime, the name of the component, if a route is needed.
  
  A `@Link` represents additional information or metadata to be injected within the `Comnponent` (aka DeploymentConfig resource)
  in order to configure the application to access another `component` using its service address, a service deployed from the k8s catalog.
 

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
  
  To express the creation of a service on the Cloud platform, we are using the `@ServiceCatalog` annotation where we define the `Service's class`, its plan and parameters.
  
  Like for the Client's component, we will also define a `@Link` annotation to inject from the secret created during the creation of the service, the parameters that the application
  will use to configure, in this example, the `DataSource`'s object able to call the `PostgreSQL` instance.
  
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
./scripts/push_start.sh fruit-client sb
./scripts/push_start.sh fruit-backend sb
```

### Check if the Component Client is replying

- Call the HTTP Endpoint exposed by the `Spring Boot Fruit Client` in order to fetch data from the database
```bash
route_address=$(oc get route/fruit-client-sb -o jsonpath='{.spec.host}')
curl http://$route_address/api/client
or 

using httpie client
http -s solarized http://$route_address/api/client
http -s solarized http://$route_address/api/client/1
http -s solarized http://$route_address/api/client/2
http -s solarized http://$route_address/api/client/3
``` 


### Using K8s

If the operator has been deployed on a k8s cluster, then use the following bash script to push the binary jar files

```bash
./scripts/k8s_push_start.sh fruit-backend sb demo
./scripts/k8s_push_start.sh fruit-client sb demo
```

**REMARK**: the namespace where the application will be deployed must be passed as 3rd paramteer to the bash script

As an ingress route will be created instead of an openshift route, then we must adapt the curl commands to access the service's address

```bash
# export FRONTEND_ROUTE_URL=<service_name>.<hostname_or_ip>.<domain_name>
export FRONTEND_ROUTE_URL=fruit-client-sb.10.0.76.186.nip.io
curl -H "Host: fruit-client-sb" ${FRONTEND_ROUTE_URL}/api/client 
```

### Switch from Dev to Build mode

- Decorate the Component with the following values in order to specify the git info needed to perform a Build, like the name of the component to be selected to switch from
  the dev loop to the publish loop

  ```bash
   annotations:
     app.openshift.io/git-uri: https://github.com/snowdrop/component-operator-demo.git
     app.openshift.io/git-ref: master
     app.openshift.io/git-dir: fruit-backend-sb
     app.openshift.io/artifact-copy-args: "*.jar"
     app.openshift.io/runtime-image: "fruit-backend-sb"
     app.openshift.io/component-name: "fruit-backend-sb"
     app.openshift.io/java-app-jar: "fruit-backend-sb-0.0.1-SNAPSHOT.jar"
  ``` 
  
  **Remark** : When the maven project does not contain multi modules, then replace the name of the folder / module with `.` using the annotation `app.openshift.io/git-dir`
  
- Patch the component when it has been deployed to switch from `dev` to `build`
  
  ```bash
  oc patch cp fruit-backend-sb -p '{"spec":{"deploymentMode":"build"}}' --type=merge
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
./scripts/push_start.sh fruit-client nodejs
```

- Test it locally or remotely
```bash
# locally
http :8080/api/client
http :8080/api/client/1 

#Remotely
route_address=$(oc get route/fruit-client-nodejs -o jsonpath='{.spec.host}')
curl http://$route_address/api/client
or 

using httpie client
http http://$route_address/api/client
http http://$route_address/api/client/1
http http://$route_address/api/client/2
http http://$route_address/api/client/3
```

### Scaffold a project


```bash
git clone git@github.com:snowdrop/scaffold-command.git && cd scaffold-command
go build -o scaffold cmd/scaffold.go
export PATH=$PATH:/Users/dabou/Code/snowdrop/scaffold-command

 scaffold   
? Create from template Yes
? Available templates rest
? Group Id me.snowdrop
? Artifact Id myproject
? Version 1.0.0-SNAPSHOT
? Package name me.snowdrop.myproject
? Spring Boot version 2.1.2.RELEASE
? Use supported version No
? Where should we create your new project ./fruit-demo

cd demo

add to the pom.xml file

<properties>
  ...
  <ap4k.version>0.3.2</ap4k.version>
</properties>
  
and 

<dependencies>
  <dependency>
    <groupId>io.ap4k</groupId>
    <artifactId>component-annotations</artifactId>
    <version>${ap4k.version}</version>
  </dependency>
  <dependency>
    <groupId>io.ap4k</groupId>
    <artifactId>kubernetes-annotations</artifactId>
    <version>${ap4k.version}</version>
  </dependency>
  <dependency>
    <groupId>io.ap4k</groupId>
    <artifactId>ap4k-spring-boot</artifactId>
    <version>${ap4k.version}</version>
  </dependency>
  <!-- spring Boot -->
  


```

## Cleanup

### Demo components

TODO: To be updated as this is not longer correct

```bash
oc delete cp/fruit-backend-sb
oc delete cp/fruit-database
oc delete cp/fruit-database-config

oc delete cp/fruit-client
oc delete cp/fruit-endpoint
```

### Operator and CRD resources

TODO: To be updated as this is not longer correct

```bash
oc delete -f resources/sa.yaml -n component-operator
oc delete -f resources/cluster-rbac.yaml
oc delete -f resources/crd.yaml 
oc delete -f resources/operator.yaml -n component-operator
```
  
