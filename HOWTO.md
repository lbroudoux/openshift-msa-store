
### Fabrique

// Depuis openshift-cases/software-factory
```
sh create-fabrique.sh
```

### Composants en DEV

// Depuis openshift-msa-store/
```
sh provision-demo.sh deploy msa-store
```

// Depuis la console OpenShift, création nouveau projet
```
oc new-project msa-store-dev --display-name="MSA Store (DEV)"
```

// Ajouter les différents composants depuis le catalogue
- Ajouter JBoss A-MQ 6.3 (no SSL) avec admin/admin
- Ajouter Apache HTTP
  shop-ui
    => http://gogs-fabric.192.168.99.100.nip.io/team/store-ui.git
    => http://gogs.fabric.svc.cluster.local:3000/team/store-ui.git
- Ajouter NodeJS - Choisir version 6
  inventory-service
    => http://gogs-fabric.192.168.99.100.nip.io/team/inventory-service.git
    => http://gogs.fabric.svc.cluster.local:3000/team/inventory-service.git

// Depuis openshift-msa-store/order-service
```
oc login https://192.168.99.100:8443
oc project msa-store-dev
mvn clean fabric8:deploy
```

// Depuis openshift-msa-store/shipping-service
```
oc login https://192.168.99.100:8443
oc project msa-store-dev
mvn clean fabric8:deploy
```

// Ouvrir le magasin sur DEV, paramétrer l'URL de order-service

http://shop-ui-msa-store-dev.192.168.99.100.nip.io
  => order-service-msa-store-dev.192.168.99.100.nip.io

### Tracing distribué et monitoring

// Modifier la configuration du DC inventory-service
Ajouter EnvVar : `JAEGER_SERVER_HOSTNAME=jaeger-agent.cockpit.svc.cluster.local`

> Ouvrir le magasin sur DEV, faire plusieurs commandes.

> Ouvrir le projet Cockpit, regarder
  - Jaeger
  - Graphana

### Composants en PROD

// Depuis openshift-msa-store/
```
oc new-project msa-store-prod --display-name="MSA Store (PROD)"
sh provision-demo.sh deploy msa-store-prod
```
> Montrer l'initialisation des DC sur un TAG d'image

// Depuis openshift-msa-store/
```
sh provision-demo.sh deploy msa-store-tag
```
> Montrer, expliquer le rollout des DC

// Ouvrir le magasin sur PROD, paramétrer l'URL de order-service

http://shop-ui-msa-store-prod.192.168.99.100.nip.io
  => order-service-msa-store-prod.192.168.99.100.nip.io

### CI/CD

// Ouvrir le projet Fabric et montrer le pipeline.
// Apporter une modification dans Gogs / inventory-service
```
|| request.params.productId === "3"
```
// Démarrer le pipeline
