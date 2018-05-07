
## Pre-requisites

### Mandatory: Components sources

This demonstration involves having all the components sources and configuration files at hand when running it. So, first thing first, start by cloning this repository.

```
git clone https://github.com/lbroudoux/openshift-msa-store.git
```

_Warning:_ The source code you've retrieved by cloning this repository will be integrated into another Git repository during demonstration. You will also use local copy for illustrating OpenShift binary builds using Maven. So be careful of cleaning all the temporaray files before running this demonstration once again. You should go to `order-service` and `shipping-service` sub-directories and run `mvn clean` before starting again.

### Mandatory: Software factory

This demonstration implies the use of embedded Source code repository and Jenkins instance for running CI/CD pipelines. We are using a utility script that povides everything for us. This script is called `create-fabrique.sh` and can be found on this [GitHub repo](https://github.com/lbroudoux/openshift-cases/tree/master/software-factory).

So start by cloning the GitHub repo, go to the `software-factory` subfolder, just `oc login` to your OpenShift environment and from the terminal execute the following :

```
sh create-fabrique.sh
```

This should start the installation process of Gogs as Source code repository, Jenkins as CI/CD orchestrator and Nexus as an artififact manager/proxy:

```
########################################################################
Creating project...
########################################################################
Creating project fabric
....
```

After few minutes, you should have everything running on your cluster.

### Optional: Monitoring cockpit

In this demonstration, you may want to show some monitoring features of microservices architecture like distributed tracing or centralized monitoring. If you want to, you may install such an infrastructure. We are using a utility script that povides everything for us. This script is called `create-cockpit.sh` and can be found on this [GitHub repo](https://github.com/lbroudoux/openshift-cases/tree/master/monitoring-cockpit).

So start by cloning the GitHub repo, go to the `monitoring-cockpit` subfolder, just `oc login` to your OpenShift environment and from the terminal execute the following :
```
sh create-cockpit.sh
```

This should start the installation process of Gogs as Source code repository, Jenkins as CI/CD orchestrator and Nexus as an artififact manager/proxy:

```
########################################################################
Creating project...
########################################################################
Creating project cockpit
....
```

After few minutes, you should have everything running on your cluster. Before starting the demonstration, you should log to Grafana and create a new datasource of type `Prometheus` pointing to local `http://prometheus:9090`.


## Development environment deployment

On your OpenShift cluster instance, start by creating a new project that will host all the components for the development environment. You can do so via the web console or the command line interface.

```
oc new-project msa-store-dev --display-name="MSA Store (DEV)"
```

Before going further, we need to import our component sources into the Gogs instance that has been provisionned with our software factory (see pre-requisites upper). In order to do that, you can just run the provided `provision-demo.sh` script from this repository root.

```
sh provision-demo.sh deploy msa-store
```

4 repositories have now been imported into your running Gogs instance. You may use user `team` with password `team` to control that everything is ok and access the web interface. Repsoitories are public, that means that you will not nedd any credentials for accessing them from OpenShift. Be sure do deploy all the coming components into the `msa-store-dev` namespace. New OCP 3.7 GUI is tricky and may replace you onto another default project.

### Infrastructure component: JBoss AMQ

From the web console, browse the catalog and choose the `JBoss A-MQ 6.3 (no SSL)` template. This is a compelling event for explaining services and templates catalogs and brokers in OpenShift. Be sure to update the Administration username and password to `admin` and `admin` in form. It is not necessary to create a Service Binding for our use-case.

### S2I "sources" components

You're now ready to deploy the first 2 components.

From the web console, browse the catalog and choose the `Apache Server` template. Through the form, name the application `shop-ui` and just reference the `store-ui` repository URL within your Git instance. This is the good time for talking about S2I, showing the build logs and telling how easy it is to let OpenShift containerize stuffs for us. But these are simply static resources, right? How does it work with build systems nd compilation?

Just deploy now the `inventoy-service` from the web console. Pick the `Node JS` template and be sure to choose `Node version 6` in the following form. Also, name the application `inventory-service` and just reference the `inventory-service` repository URL within your Git instance. Once again, talk abount S2I and sho through the build log how OpenShift is detecting the presence of a NPM builder and execute and `npm install` for us in order to retrieve the dependencies before containerisation. But once again, this is not a compilation right?

### S2I "binary" components

You may choose to deploy the 2 other components using specific templates in the same manner to demonstrate how OpenShift detect a Maven build and realize the retrieval of dependencies, the compilatation, the tests and the packaging before containerizing. However, this take usually many times due to Maven stuffs...

I personnalyy prefer talking about the developer inner-loop workflow: the operations he should realize many times a day to deploy the code that being developed and not yet committed. So basically, use the terminal and `oc login` to your OpenShift instance. Be sure to be positionned onto the correct project:

```
oc project msa-store-dev
```

Now, just build and deploy the 2 Java components by running the following commands:

```
cd order-service
mvn fabric8:deploy
cd ../shipping-service
mvn fabric8:deploy
```

After some time, you should have all the components along side the JBoss AMQ broker running.

### Test

It's now time to check and see that everyhting is running, so get the route that was created on the `shop-ui` component and open it into a brower. Also, be sure to get the hostname for `order-service` because our UI will need it for calling the service REST API. This should normmally be something like `order-service-msa-store-dev.apps.example.com` where you replace domain by yours. Copy/paste this hostname in input field on top rigt of the shop ui, clcik outside of input and place some orders. Only the 1st Shadow man t-shirt should be available within inventory.

![shop-ui](https://raw.githubusercontent.com/lbroudoux/openshift-msa-store/master/assets/shop-ui.png)


## Monitoring stuffs for microservices

This is an optional part. In pre-requisites, you may have installed (or not) the monitoring infrastructure.

Having the application now deployed is a good event for having a discussion about monitoring in a distributed world. How do you ensure that everything is running and that components talk to each other in the expected way? You may want to use distributed tracing for that! Red Hat (through its CNCF contribution) supports Open Tracing standard and Jaeger is the implementation that can be easily deployed in OpenShift.

The 2 Java components of our demo are already configured to support Open Tracing and to talk to the Jaeger instance running into `cockpit` project. Being an open standard, Open Tracing has also implementation in Node JS and our `inventory-service` has been prepared to support it. The only missing part is the URL of the Jaeger server. So if you want to illustrate that point, you should go to the `inventory-service` DeploymentConfig and add a new Environment Variable:
 * `JAEGER_SERVER_HOSTNAME` having the value `jaeger-agent.cockpit.svc.cluster.local`

Just save the configuration and see the corresponding pod redeploy automatically. This is the good moment to talk about centralized configuration management into distributed, cloud-native applications ;-)

Now that everything has been redeployed, just test the application once again and place a few orders. You should now be able to access Jaeger UI through the route created in Cockpit project and check that there's a few traces present into Jaeger.

![jaeger-tracing](https://raw.githubusercontent.com/lbroudoux/openshift-msa-store/master/assets/jaeger-tracing.png)

Second part of monitoring stuffs is about enabling Prometheus metrics scraping and demonstrating Grafana capabilities for building nice dasboards. Once again, the 2 Java components have already been prepared for exposing Prometheus metrics through sepcific endpoint. The only thing you'll have to do to enable scraping is to update the Prometheus configuration with the yaml snippet provided into [msa-store-prometheus-config.yml](https://raw.githubusercontent.com/lbroudoux/openshift-msa-store/master/msa-store-prometheus-config.yml) file. Just copy/paste this snippet within the `prometheus` Config Map within `cockpit` project under the `prometheus.yml` file. You'll have to delete the `prometheus-0` pod of statefulset to force refresh of configuration. This part can be done in anticipation of the demonstration.

Now you should be able to visualize the default dashboard displaying the OpenShift cluster health as well as creating a new dashboard for our specific MSA Store application. Exemple for such a dashboard is provided within the [msa-store-grafana-dashboard.json](https://raw.githubusercontent.com/lbroudoux/openshift-msa-store/master/msa-store-grafana-dashboard.json) file.

You should achieve this kind of result:
 * A 1st chart displaying the JVM Heap Size for the 2 Java components,
 * A 2nd chart displaying processing time of messages within the 2 Java components.

![prometheus-monitoring](https://raw.githubusercontent.com/lbroudoux/openshift-msa-store/master/assets/prometheus-monitoring.png)


## Production environment deployment

Now it's time to wonder how to put everything we did into production... Gonna do all this manual deployment once again? Clearly no, it's not the philosophy behind immutable containers! So we start by creating a new environment and use the provisionning script to prepare all the objects we'll need for deployment.

Let execute the script after having `oc login` to the OpenShift cluster:

```
oc new-project msa-store-prod --display-name="MSA Store (PROD)"
sh provision-demo.sh deploy msa-store-prod
```

Once finished, we can browse the newly created porject and check that all Deployment Config object have been created and that they're cleraly referencing the Image Stream from Dev environment with a specific `promoteToProd` tag. It is time to explain the promotion logic of containers from environment to environment.

Do not forget to also add the `JBoss A-MQ 6.3 (no ssl)` component like we did into development environment using an `admin/admin` username/password combination.

The following script manage to tag all the development image for you and roll outs the deployment for each object.

```
sh provision-demo.sh deploy msa-store-tag
```

Once deplouments are OK, the application should now be available onto production environment route for `shop-ui` component.

### CI/CD

Finally, how to automate deployment, testing and promotion of each new changes made to code source? The previous script has also created a CI/CD pipeline configuration for the `inventory-service` component. In order to illustrate it, you can simulate a simple change within the component source code.

For now, only the first t-shirt of our product catalogue is available into inventory. Let say that we have received new items for the third t-shirt. Connect to the Gogs repository URL and locate the `app.js` file within `inventory-service` repository. And do a simple addition on line conditionning the response returned to `order-service`. You may add this simple OR condition and save/commit the file.

```
|| req.params.productId === "3"
```

After that, just go to the `fabric` project and within the _Builds > Pipelines_ section of web console, start the new `inventory-service-pipeline` pipeline. You shoud end up with the following executed pipeline and should be able to experiment the committed change.

![inventory-service-pipeline](https://raw.githubusercontent.com/lbroudoux/openshift-msa-store/master/assets/inventory-service-pipeline.png)

## Some more demo ideas or variations
