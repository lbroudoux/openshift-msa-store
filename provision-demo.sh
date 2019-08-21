#!/bin/bash
################################################################################
# Provisioning script to deploy the demos on an OpenShift environment  #
################################################################################

function usage() {
    echo
    echo "Usage:"
    echo " $0 [command] [demo-name] [options]"
    echo " $0 --help"
    echo
    echo "Example:"
    echo " $0 deploy --maven-mirror-url http://nexus.repo.com/content/groups/public/ --project-suffix mydemo"
    echo
    echo "COMMANDS:"
    echo "   deploy                   Set up the demo projects and deploy demo apps"
    echo "   delete                   Clean up and remove demo projects and objects"
    echo "   idle                     Make all demo services idle"
    echo "   unidle                   Make all demo services unidle"
    echo
    echo "DEMOS:"
    echo "   msa-store                Store using Microservices architecture"
    echo "   msa-store-prod           Prouction environ for msa-store (source: msa-store-dev)"
    echo
    echo "OPTIONS:"
    echo "   --user [username]         The admin user for the demo projects. mandatory if logged in as system:admin"
    echo "   --maven-mirror-url [url]  Use the given Maven repository for builds. If not specifid, a Nexus container is deployed in the demo"
    echo "   --project-suffix [suffix] Suffix to be added to demo project names e.g. ci-SUFFIX. If empty, user will be used as suffix"
    echo
}

ARG_COMMAND=
ARG_DEMO=

while :; do
    case $1 in
        deploy)
            ARG_COMMAND=deploy
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        delete)
            ARG_COMMAND=delete
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        idle)
            ARG_COMMAND=idle
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        unidle)
            ARG_COMMAND=unidle
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        --user)
            if [ -n "$2" ]; then
                ARG_USERNAME=$2
                shift
            else
                printf 'ERROR: "--user" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --maven-mirror-url)
            if [ -n "$2" ]; then
                ARG_MAVEN_MIRROR_URL=$2
                shift
            else
                printf 'ERROR: "--maven-mirror-url" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --project-suffix)
            if [ -n "$2" ]; then
                ARG_PROJECT_SUFFIX=$2
                shift
            else
                printf 'ERROR: "--project-suffix" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            shift
            ;;
        *) # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done

################################################################################
# CONFIGURATION                                                                #
################################################################################

#DOMAIN="192.168.99.100.nip.io"
DOMAIN=""
PRJ_CI=("fabric" "CI/CD Fabric" "CI/CD Components (Jenkins, Gogs, etc)")
GOGS_ROUTE="gogs-${PRJ_CI[0]}.$DOMAIN"

GOGS_USER=developer
GOGS_PASSWORD=developer
GOGS_ADMIN_USER=team
GOGS_ADMIN_PASSWORD=team

function echo_header() {
  echo
  echo "########################################################################"
  echo $1
  echo "########################################################################"
}

# Waits while the condition is true until it becomes false or it times out
function wait_while_empty() {
  local _NAME=$1
  local _TIMEOUT=$(($2/5))
  local _CONDITION=$3

  echo "Waiting for $_NAME to be ready..."
  local x=1
  while [ -z "$(eval ${_CONDITION})" ]
  do
    echo "."
    sleep 5
    x=$(( $x + 1 ))
    if [ $x -gt $_TIMEOUT ]
    then
      echo "$_NAME still not ready, I GIVE UP!"
      exit 255
    fi
  done

  echo "$_NAME is ready."
}

function provision_msa_store() {
  echo_header "Deploying MSA Store demo..."

  # hack for getting default domain for routes.
  if [ "x$DOMAIN" = "x" ]; then
    DOMAIN=$(oc get route docker-registry -o template --template='{{.spec.host}}' -n default | sed "s/docker-registry-default.//g")
    GOGS_ROUTE="gogs-${PRJ_CI[0]}.$DOMAIN"
  fi

  # add admin user
  _RETURN=$(curl -o /dev/null -sL --post302 -w "%{http_code}" http://$GOGS_ROUTE/user/sign_up \
    --form user_name=$GOGS_ADMIN_USER \
    --form password=$GOGS_ADMIN_PASSWORD \
    --form retype=$GOGS_ADMIN_PASSWORD \
    --form email=$GOGS_ADMIN_USER@gogs.com)
  sleep 5

  # import GitHub repo
  read -r -d '' _DATA_JSON << EOM
{
  "name": "order-service",
  "private": false
}
EOM

  echo "Creating repository order-service on Gogs"
  _RETURN=$(curl -o /dev/null -sL -w "%{http_code}" -H "Content-Type: application/json" -d "$_DATA_JSON" -u $GOGS_ADMIN_USER:$GOGS_ADMIN_PASSWORD -X POST http://$GOGS_ROUTE/api/v1/user/repos)
  if [ $_RETURN != "201" ] && [ $_RETURN != "200" ] ; then
    echo "WARNING: Failed (http code $_RETURN) to create repository"
  else
    echo "order-service repo created"
  fi
  sleep 2

  local _CUR_DIR=$PWD
  local _REPO_DIR=/tmp/$(date +%s)-order-service
  echo "Pushing local sources on Gogs order-service repository"
  pushd ~ >/dev/null && \
      rm -rf $_REPO_DIR && \
      mkdir $_REPO_DIR && \
      cd $_REPO_DIR && \
      git init && \
      cp -R $_CUR_DIR/order-service/ . && \
      git remote add origin http://$GOGS_ROUTE/$GOGS_ADMIN_USER/order-service.git && \
      git add . --all && \
      git config user.email "lbroudou@redhat.com" && \
      git config user.name "Laurent Broudoux" && \
      git commit -m "Initial add" && \
      git push -f http://$GOGS_ADMIN_USER:$GOGS_ADMIN_PASSWORD@$GOGS_ROUTE/$GOGS_ADMIN_USER/order-service.git master && \
      popd >/dev/null && \
      rm -rf $_REPO_DIR
  sleep 2

  # import GitHub repo
  read -r -d '' _DATA_JSON << EOM
{
  "name": "shipping-service",
  "private": false
}
EOM

  echo "Creating repository shipping-service on Gogs"
  _RETURN=$(curl -o /dev/null -sL -w "%{http_code}" -H "Content-Type: application/json" -d "$_DATA_JSON" -u $GOGS_ADMIN_USER:$GOGS_ADMIN_PASSWORD -X POST http://$GOGS_ROUTE/api/v1/user/repos)
  if [ $_RETURN != "201" ] && [ $_RETURN != "200" ] ; then
    echo "WARNING: Failed (http code $_RETURN) to create repository"
  else
    echo "shipping-service repo created"
  fi
  sleep 2

  local _CUR_DIR=$PWD
  local _REPO_DIR=/tmp/$(date +%s)-shipping-service
  echo "Pushing local sources on Gogs shipping-service repository"
  pushd ~ >/dev/null && \
      rm -rf $_REPO_DIR && \
      mkdir $_REPO_DIR && \
      cd $_REPO_DIR && \
      git init && \
      cp -R $_CUR_DIR/shipping-service/ . && \
      git remote add origin http://$GOGS_ROUTE/$GOGS_ADMIN_USER/shipping-service.git && \
      git add . --all && \
      git config user.email "lbroudou@redhat.com" && \
      git config user.name "Laurent Broudoux" && \
      git commit -m "Initial add" && \
      git push -f http://$GOGS_ADMIN_USER:$GOGS_ADMIN_PASSWORD@$GOGS_ROUTE/$GOGS_ADMIN_USER/shipping-service.git master && \
      popd >/dev/null && \
      rm -rf $_REPO_DIR
  sleep 2

  # import GitHub repo
  read -r -d '' _DATA_JSON << EOM
{
  "name": "inventory-service",
  "private": false
}
EOM

  echo "Creating repository inventory-service on Gogs"
  _RETURN=$(curl -o /dev/null -sL -w "%{http_code}" -H "Content-Type: application/json" -d "$_DATA_JSON" -u $GOGS_ADMIN_USER:$GOGS_ADMIN_PASSWORD -X POST http://$GOGS_ROUTE/api/v1/user/repos)
  if [ $_RETURN != "201" ] && [ $_RETURN != "200" ] ; then
    echo "WARNING: Failed (http code $_RETURN) to create repository"
  else
    echo "inventory-service repo created"
  fi
  sleep 2

  local _CUR_DIR=$PWD
  local _REPO_DIR=/tmp/$(date +%s)-inventory-service
  echo "Pushing local sources on Gogs inventory-service repository"
  pushd ~ >/dev/null && \
      rm -rf $_REPO_DIR && \
      mkdir $_REPO_DIR && \
      cd $_REPO_DIR && \
      git init && \
      cp -R $_CUR_DIR/inventory-service/ . && \
      git remote add origin http://$GOGS_ROUTE/$GOGS_ADMIN_USER/inventory-service.git && \
      git add . --all && \
      git config user.email "lbroudou@redhat.com" && \
      git config user.name "Laurent Broudoux" && \
      git commit -m "Initial add" && \
      git push -f http://$GOGS_ADMIN_USER:$GOGS_ADMIN_PASSWORD@$GOGS_ROUTE/$GOGS_ADMIN_USER/inventory-service.git master && \
      popd >/dev/null && \
      rm -rf $_REPO_DIR
  sleep 2


  # import GitHub repo
  read -r -d '' _DATA_JSON << EOM
{
  "name": "store-ui",
  "private": false
}
EOM

  echo "Creating repository store-ui on Gogs"
  _RETURN=$(curl -o /dev/null -sL -w "%{http_code}" -H "Content-Type: application/json" -d "$_DATA_JSON" -u $GOGS_ADMIN_USER:$GOGS_ADMIN_PASSWORD -X POST http://$GOGS_ROUTE/api/v1/user/repos)
  if [ $_RETURN != "201" ] && [ $_RETURN != "200" ] ; then
    echo "WARNING: Failed (http code $_RETURN) to create repository"
  else
    echo "store-ui repo created"
  fi
  sleep 2

  local _CUR_DIR=$PWD
  local _REPO_DIR=/tmp/$(date +%s)-store-ui
  echo "Pushing local sources on Gogs store-ui repository"
  pushd ~ >/dev/null && \
      rm -rf $_REPO_DIR && \
      mkdir $_REPO_DIR && \
      cd $_REPO_DIR && \
      git init && \
      cp -R $_CUR_DIR/store-ui/ . && \
      git remote add origin http://$GOGS_ROUTE/$GOGS_ADMIN_USER/store-ui.git && \
      git add . --all && \
      git config user.email "lbroudou@redhat.com" && \
      git config user.name "Laurent Broudoux" && \
      git commit -m "Initial add" && \
      git push -f http://$GOGS_ADMIN_USER:$GOGS_ADMIN_PASSWORD@$GOGS_ROUTE/$GOGS_ADMIN_USER/store-ui.git master && \
      popd >/dev/null && \
      rm -rf $_REPO_DIR
  sleep 2
}

function provision_msa_store_prod() {
  echo_header "Deploying MSA Store production environment..."

  # Create prod project
  oc new-project msa-store-prod --display-name="MSA Store (PROD)"

  # Adjust project permissions
  oc adm policy add-role-to-user edit system:serviceaccount:${PRJ_CI[0]}:jenkins -n msa-store-dev
  oc adm policy add-role-to-user edit system:serviceaccount:${PRJ_CI[0]}:jenkins -n msa-store-prod

  # Allow test and prod to pull from dev
  oc adm policy add-role-to-group system:image-puller system:serviceaccounts:msa-store-prod -n msa-store-dev

  # After having created development bc, dc, svc, routes
  oc create deploymentconfig order-service --image=docker-registry.default.svc:5000/msa-store-dev/order-service:promoteToProd -n msa-store-prod
  oc set env dc/order-service ACTIVEMQ_SERVICE_NAME=broker-amq-tcp JAEGER_SERVER_HOSTNAME=jaeger-agent.cockpit.svc.cluster.local JAVA_OPTIONS=-javaagent:agent/jmx_prometheus_javaagent-0.10.jar=9779:agent/config.yml JAVA_APP_DIR=/deployments -n msa-store-prod

  oc create deploymentconfig inventory-service --image=docker-registry.default.svc:5000/msa-store-dev/inventory-service:promoteToProd -n msa-store-prod
  oc set env dc/inventory-service PORT=8080 JAEGER_SERVER_HOSTNAME=jaeger-agent.cockpit.svc.cluster.local

  oc create deploymentconfig shipping-service --image=docker-registry.default.svc:5000/msa-store-dev/shipping-service:promoteToProd -n msa-store-prod
  oc set env dc/shipping-service ACTIVEMQ_SERVICE_NAME=broker-amq-tcp JAEGER_SERVER_HOSTNAME=jaeger-agent.cockpit.svc.cluster.local JAVA_OPTIONS=-javaagent:agent/jmx_prometheus_javaagent-0.10.jar=9779:agent/config.yml JAVA_APP_DIR=/deployments -n msa-store-prod

  oc create deploymentconfig shop-ui --image=docker-registry.default.svc:5000/msa-store-dev/shop-ui:promoteToProd -n msa-store-prod

  oc rollout cancel dc/order-service -n msa-store-prod
  oc rollout cancel dc/inventory-service -n msa-store-prod
  oc rollout cancel dc/shipping-service -n msa-store-prod
  oc rollout cancel dc/shop-ui -n msa-store-prod

  oc set triggers dc/order-service --manual=true --from-config=false -n msa-store-prod
  oc set triggers dc/inventory-service --manual=true --from-config=false -n msa-store-prod
  oc set triggers dc/shipping-service --manual=true --from-config=false -n msa-store-prod
  oc set triggers dc/shop-ui --manual=true --from-config=false -n msa-store-prod

  oc set triggers dc/order-service --manual=true --containers=default-container --from-image=msa-store-dev/order-service:promoteToProd -n msa-store-prod
  oc set triggers dc/inventory-service --manual=true --containers=default-container --from-image=msa-store-dev/inventory-service:promoteToProd -n msa-store-prod
  oc set triggers dc/shipping-service --manual=true --containers=default-container --from-image=msa-store-dev/shipping-service:promoteToProd -n msa-store-prod
  oc set triggers dc/shop-ui --manual=true --containers=default-container --from-image=msa-store-dev/shop-ui:promoteToProd -n msa-store-prod

  oc get dc order-service -o yaml -n msa-store-prod | sed 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Always/g' | oc replace -f -
  oc get dc inventory-service -o yaml -n msa-store-prod | sed 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Always/g' | oc replace -f -
  oc get dc shipping-service -o yaml -n msa-store-prod | sed 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Always/g' | oc replace -f -
  oc get dc shop-ui -o yaml -n msa-store-prod | sed 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Always/g' | oc replace -f -

  oc expose dc order-service --port=80 --target-port=8181 -n msa-store-prod
  oc expose dc inventory-service --port=8080 -n msa-store-prod
  oc expose dc shipping-service --port=80 --target-port=8080 -n msa-store-prod
  oc expose dc shop-ui --port=8080 -n msa-store-prod

  oc expose svc order-service --port=8181 -n msa-store-prod
  oc expose svc shop-ui --port=8080 -n msa-store-prod

  oc new-app --template=amq63-persistent --name=amq63-persistent \
    --param=APPLICATION_NAME=broker \
    --param=MQ_USERNAME=admin \
    --param=MQ_PASSWORD=admin \
    --param=AMQ_STORAGE_USAGE_LIMIT=10gb \
    --param=AMQ_QUEUE_MEMORY_LIMIT=1gb
}

function provision_msa_store_tag() {
  echo_header "Tagging MSA Store development images and deploying..."

  oc tag msa-store-dev/order-service:latest msa-store-dev/order-service:promoteToProd
  oc tag msa-store-dev/inventory-service:latest msa-store-dev/inventory-service:promoteToProd
  oc tag msa-store-dev/shipping-service:latest msa-store-dev/shipping-service:promoteToProd
  oc tag msa-store-dev/shop-ui:latest msa-store-dev/shop-ui:promoteToProd

  oc rollout latest dc/order-service -n msa-store-prod
  oc rollout latest dc/inventory-service -n msa-store-prod
  oc rollout latest dc/shipping-service -n msa-store-prod
  oc rollout latest dc/shop-ui -n msa-store-prod

  oc create -f pipeline.yml -n ${PRJ_CI[0]}
}

function provision_msa_store_prod_bg() {
  echo_header "Deploying MSA Store production environment..."

  # Create prod project
  oc new-project msa-store-prod --display-name="MSA Store (PROD)"

  # Adjust project permissions
  oc adm policy add-role-to-user edit system:serviceaccount:${PRJ_CI[0]}:jenkins -n msa-store-dev
  oc adm policy add-role-to-user edit system:serviceaccount:${PRJ_CI[0]}:jenkins -n msa-store-prod

  # Allow test and prod to pull from dev
  oc adm policy add-role-to-group system:image-puller system:serviceaccounts:msa-store-prod -n msa-store-dev

  # After having created development bc, dc, svc, routes
  oc create deploymentconfig order-service --image=docker-registry.default.svc:5000/msa-store-dev/order-service:promoteToProd -n msa-store-prod
  oc set env dc/order-service ACTIVEMQ_SERVICE_NAME=broker-amq-tcp JAEGER_SERVER_HOSTNAME=jaeger-agent.cockpit.svc.cluster.local JAVA_OPTIONS=-javaagent:agent/jmx_prometheus_javaagent-0.10.jar=9779:agent/config.yml JAVA_APP_DIR=/deployments -n msa-store-prod

  # blue
  oc create deploymentconfig inventory-service-blue --image=docker-registry.default.svc:5000/msa-store-dev/inventory-service:promoteToProd -n msa-store-prod
  oc set env dc/inventory-service-blue PORT=8080 JAEGER_SERVER_HOSTNAME=jaeger-agent.cockpit.svc.cluster.local
  oc label dc inventory-service-blue color=blue
  # green
  oc create deploymentconfig inventory-service-green --image=docker-registry.default.svc:5000/msa-store-dev/inventory-service:promoteToProd -n msa-store-prod
  oc set env dc/inventory-service-green PORT=8080 JAEGER_SERVER_HOSTNAME=jaeger-agent.cockpit.svc.cluster.local
  oc label dc inventory-service-green color=green

  oc create deploymentconfig shipping-service --image=docker-registry.default.svc:5000/msa-store-dev/shipping-service:promoteToProd -n msa-store-prod
  oc set env dc/shipping-service ACTIVEMQ_SERVICE_NAME=broker-amq-tcp JAEGER_SERVER_HOSTNAME=jaeger-agent.cockpit.svc.cluster.local JAVA_OPTIONS=-javaagent:agent/jmx_prometheus_javaagent-0.10.jar=9779:agent/config.yml JAVA_APP_DIR=/deployments -n msa-store-prod

  oc create deploymentconfig shop-ui --image=docker-registry.default.svc:5000/msa-store-dev/shop-ui:promoteToProd -n msa-store-prod

  oc rollout cancel dc/order-service -n msa-store-prod
  oc rollout cancel dc/inventory-service-blue -n msa-store-prod
  oc rollout cancel dc/inventory-service-green -n msa-store-prod
  oc rollout cancel dc/shipping-service -n msa-store-prod
  oc rollout cancel dc/shop-ui -n msa-store-prod

  oc set triggers dc/order-service --manual=true --from-config=false -n msa-store-prod
  oc set triggers dc/inventory-service-blue --manual=true --from-config=false -n msa-store-prod
  oc set triggers dc/inventory-service-green --manual=true --from-config=false -n msa-store-prod
  oc set triggers dc/shipping-service --manual=true --from-config=false -n msa-store-prod
  oc set triggers dc/shop-ui --manual=true --from-config=false -n msa-store-prod

  oc set triggers dc/order-service --manual=true --containers=default-container --from-image=msa-store-dev/order-service:promoteToProd -n msa-store-prod
  oc set triggers dc/inventory-service-blue --manual=true --containers=default-container --from-image=msa-store-dev/inventory-service:promoteToProd -n msa-store-prod
  oc set triggers dc/inventory-service-green --manual=true --containers=default-container --from-image=msa-store-dev/inventory-service:promoteToProd -n msa-store-prod
  oc set triggers dc/shipping-service --manual=true --containers=default-container --from-image=msa-store-dev/shipping-service:promoteToProd -n msa-store-prod
  oc set triggers dc/shop-ui --manual=true --containers=default-container --from-image=msa-store-dev/shop-ui:promoteToProd -n msa-store-prod

  oc patch dc inventory-service-blue -p '{"spec":{"template":{"metadata":{"labels":{"color":"blue"}}}}}' -n msa-store-prod
  oc patch dc inventory-service-green -p '{"spec":{"template":{"metadata":{"labels":{"color":"green"}}}}}' -n msa-store-prod
  
  oc get dc order-service -o yaml -n msa-store-prod | sed 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Always/g' | oc replace -f -
  oc get dc inventory-service-blue -o yaml -n msa-store-prod | sed 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Always/g' | oc replace -f -
  oc get dc inventory-service-green -o yaml -n msa-store-prod | sed 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Always/g' | oc replace -f -
  oc get dc shipping-service -o yaml -n msa-store-prod | sed 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Always/g' | oc replace -f -
  oc get dc shop-ui -o yaml -n msa-store-prod | sed 's/imagePullPolicy: IfNotPresent/imagePullPolicy: Always/g' | oc replace -f -

  oc expose dc order-service --port=80 --target-port=8181 -n msa-store-prod
  oc expose dc inventory-service-blue --port=8080 --selector="color=blue" -n msa-store-prod
  oc expose dc inventory-service-green --port=8080 --selector="color=green" -n msa-store-prod
  oc expose dc inventory-service-blue --name="inventory-service" --port=8080 --selector="color=blue" -n msa-store-prod
  oc expose dc shipping-service --port=80 --target-port=8080 -n msa-store-prod
  oc expose dc shop-ui --port=8080 -n msa-store-prod

  oc expose svc order-service --port=8181 -n msa-store-prod
  oc expose svc shop-ui --port=8080 -n msa-store-prod

  oc new-app --template=amq63-persistent --name=amq63-persistent \
    --param=APPLICATION_NAME=broker \
    --param=MQ_USERNAME=admin \
    --param=MQ_PASSWORD=admin \
    --param=AMQ_STORAGE_USAGE_LIMIT=10gb \
    --param=AMQ_QUEUE_MEMORY_LIMIT=1gb
}

function provision_msa_store_tag_bg() {
  echo_header "Tagging MSA Store development images and deploying..."

  oc tag msa-store-dev/order-service:latest msa-store-dev/order-service:promoteToProd
  oc tag msa-store-dev/inventory-service:latest msa-store-dev/inventory-service:promoteToProd
  oc tag msa-store-dev/shipping-service:latest msa-store-dev/shipping-service:promoteToProd
  oc tag msa-store-dev/shop-ui:latest msa-store-dev/shop-ui:promoteToProd

  oc rollout latest dc/order-service -n msa-store-prod
  oc rollout latest dc/inventory-service-blue -n msa-store-prod
  oc rollout latest dc/inventory-service-green -n msa-store-prod
  oc rollout latest dc/shipping-service -n msa-store-prod
  oc rollout latest dc/shop-ui -n msa-store-prod

  oc create -f pipeline-bg.yml -n ${PRJ_CI[0]}
}


################################################################################
# MAIN: DEPLOY DEMOS                                                           #
################################################################################

case "$ARG_COMMAND" in
    deploy)
      if [ "$ARG_DEMO" = "msa-store" ] ; then
        provision_msa_store
      elif [ "$ARG_DEMO" = "msa-store-prod" ] ; then
        provision_msa_store_prod
      elif [ "$ARG_DEMO" = "msa-store-prod-bg" ] ; then
        provision_msa_store_prod_bg
      elif [ "$ARG_DEMO" = "msa-store-tag" ] ; then
        provision_msa_store_tag
      elif [ "$ARG_DEMO" = "msa-store-tag-bg" ] ; then
        provision_msa_store_tag_bg
      fi
      ;;
    delete)
      ;;
    idle)
      ;;
    unidle)
      ;;
    *)
      echo "Invalid command specified: '$ARG_COMMAND'"
      usage
      ;;
esac
