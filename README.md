# Microservices Architectured Store on OpenShift

This demonstration helps demonstrate how [OpenShift](http://www.openshift.org) can be used as a platform for building, distributing, running and monitoring Microservices application made of different runtimes and technologies. The demonstration focus of different concerns of MSA: from service discovery to scheduling, going through configuration maangement, log centralization and so on.

The business scenario used is the one of a naive Web Store that allows you to choose and order Red Hat t-shirts (but it can be easily adapt to sell anything else ;-)). The scenario implies 5 main components deployed as Pods on OpenShift using different deployment methods.


## Architecture overview

The demonstration use-case is built on 5 elements like shown in picture below.

![architecture](https://raw.githubusercontent.com/lbroudoux/openshift-msa-store/master/assets/architecture.png)

From left to right, we've got:
* Shop Web UI (`SHOP` box) is responsible for interacting with end-users. It is simple page application written using HTML, CSS and Jaavscript technologies. It will be hosted into a simple `Apache HTTP` based container,
* Order Service (`ORDER` box) is responsible for recording orders. Before doing do, he should ensure that product requested by user are is available by consulting inventory. It is implemented using `Red Hat JBoss Fuse` based container,
* Inventory Service (`INVENTORY` box) is responsible for managing inventory. It exposed simple REST API telling if a product is available given its id. It is implemented using `NodeJS` based container,
* Messaging middleware (`MQ` cylinder) is responsible for transmitting messages from Order service to Shipping service once it has been confirmed that product ordered is available. It is implemented using `Red Hat JBoss A-MQ` based container,
* Shipping Service (`SHIPPING` box) is responsible for processing the order and managing the delivery of product to customer. It is implemented using `Spring Boot` based container.

### UI overview 

The UI of the shop is really straightforward: you simply select your item and enter desired quantity on the left pane. The right pane is used for system messages: telling you of item is available and thus ordered recorded, or not.

![shop-ui](https://raw.githubusercontent.com/lbroudoux/openshift-msa-store/master/assets/shop-ui.png)


## Installing and using

### Pre-requisites

It is assumed that you have some kind of OpenShift cluster instance running and available. This instance can take several forms depending on your environment and needs :
* Full blown OpenShift cluster at your site, see how to [Install OpenShift at your site](https://docs.openshift.com/container-platform/3.7/install_config/index.html),
* Red Hat Container Development Kit on your laptop, see how to [Get Started with CDK](http://developers.redhat.com/products/cdk/get-started/),
* Lightweight Minishift on your laptop, see [Minishift project page](https://github.com/minishift/minishift).

You should also have the `oc` client line interface tool installed on your machine. Pick the corresponding OpenShift version from [this page](https://github.com/openshift/origin/releases).

Once your OpenShift instance is up and running, ensure you've got the Red Hat Fuse Integration Services images installed onto OpenShift. You can check this going to the catalogue view of OpenShift web console. If not present, you can run the following command for installing missing image streams and templates :

    oc create -f https://raw.githubusercontent.com/openshift/openshift-ansible/master/roles/openshift_examples/files/examples/v3.7/xpaas-streams/fis-image-streams.json -n openshift
    oc create -f https://raw.githubusercontent.com/openshift/openshift-ansible/master/roles/openshift_examples/files/examples/v3.7/xpaas-streams/jboss-image-streams.json -n openshift
    oc create -f https://raw.githubusercontent.com/openshift/openshift-ansible/master/roles/openshift_examples/files/examples/v3.7/xpaas-templates/amq63-basic.json -n openshift

You need now to deploy a JBoss A-MQ instance in order to later deploy the project's modules.

### Demoing

Everything is explained in this [HOWTO-DEMO](./HOWTO-DEMO.md) !