#!/bin/bash

set -e

depid=${1:-$(hexdump -n 4 -e '"%08X" 1 ""' /dev/random | tr '[:upper:]' '[:lower:]')}

source ./az_prefs

prefix=${prefix:="ocp"}
location=${location:="West Europe"}
main_password=${main_password:=$(hexdump -n 16 -e '"%08X" 1 ""' /dev/random)}
image_type=${image_type:="byoi"}
artifacts_location=${artifacts_location:="https://raw.githubusercontent.com/duritong/openshift-container-platform/master"}
dns_type=${dns_type:="default"}

if [ -z $subscription ]; then
  echo "Require to set subscription"
  exit 1
fi
if [ "${image_type}" == 'byoi' ] && [ -z "${image_src}" ]; then
  echo "Require to set image_source"
  exit 1
fi
if [ -z $rhsm_org_id ]; then
  echo "Require to set rhsm_org_id"
  exit 1
fi
if [ -z $rhsm_activation_key ]; then
  echo "Require to set rhsm_activation_key"
  exit 1
fi
if [ -z $rhsm_pool_id ]; then
  echo "Require to set rhsm_pool_id"
  exit 1
fi

if [ "${dns_type}" == "custom" ] && [ [ -z $dns_master ] || [ -z $dns_apps ] ] ; then
  echo "Need to set dns_master and dns_apps if you want custom as dns_type"
  exit 1
fi

if [ "${dns_type}" == "default" ]; then
  dns_type_apps="nipio"
fi

rg="${prefix}-${depid}"

echo "Creating ResourceGroup ${rg}"

mkdir $rg
ssh-keygen -t rsa -b 4096 -f $rg/id_rsa -N ''

az group create -n $rg -l 'West Europe'

kv_name="kv-${rg}"

az keyvault create -n $kv_name -g $rg -l "${location}" --enabled-for-template-deployment true

az keyvault secret set --vault-name $kv_name -n SecretName --file $rg/id_rsa

ad_id=$(az ad sp create-for-rbac -n ocp-cp-${rg} --password ${main_password} --role contributor --scopes /subscriptions/${subscription}/resourceGroups/${rg} | jq .appId | sed 's/"//g') 

cat <<EOF > ./${rg}/ocp.json
{
  "\$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "_artifactsLocation": {
      "value": "${artifacts_location}"
    },
    "masterVmSize": {
      "value": "Standard_E2s_v3"
    },
    "infraVmSize": {
      "value": "Standard_D4s_v3"
    },
    "nodeVmSize": {
      "value": "Standard_D4s_v3"
    },
    "cnsVmSize": {
      "value": "Standard_E4s_v3"
    },
    "osImageType": {
      "value": "${image_type}"
    },
    "marketplaceOsImage": {
      "value": {
        "publisher": "RedHat",
        "offer": "rhel-byos",
        "sku": "rhel-lvm75",
        "version": "latest"
      }
    },
    "imageReference": {
      "value": {
        "id": "${image_src}"
      }
    },
    "storageKind": {
      "value": "managed"
    },
    "openshiftClusterPrefix": {
      "value": "${rg}"
    },
    "masterInstanceCount": {
      "value": 3
    },
    "infraInstanceCount": {
      "value": 2
    },
    "nodeInstanceCount": {
      "value": 3
    },
    "dataDiskSize": {
      "value": 128
    },
    "adminUsername": {
      "value": "ocpadmin"
    },
    "openshiftPassword": {
      "value": "${main_password}"
    },
    "enableMetrics": {
      "value": "true"
    },
    "enableLogging": {
      "value": "true"
    },
    "enableCNS": {
      "value": "false"
    },
    "rhsmUsernameOrOrgId": {
      "value": "${rhsm_org_id}"
    },
    "rhsmPasswordOrActivationKey": {
      "value": "${rhsm_activation_key}"
    },
    "rhsmPoolId": {
      "value": "${rhsm_pool_id}"
    },
    "rhsmBrokerPoolId": {
      "value": "${rhsm_broker_pool_id:=$rhsm_pool_id}"
    },
    "sshPublicKey": {
      "value": "$(cat $rg/id_rsa.pub | tr -d '\n')"
    },
    "keyVaultResourceGroup": {
      "value": "${rg}"
    },
    "keyVaultName": {
      "value": "${kv_name}"
    },
    "keyVaultSecret": {
      "value": "SecretName"
    },
    "enableAzure": {
      "value": "true"
    },
    "aadClientId": {
      "value": "${ad_id}"
    },
    "aadClientSecret": {
      "value": "${main_password}"
    },
    "masterClusterDnsType": {
      "value": "${dns_type}"
    },
    "masterClusterDns": {
      "value": "${dns_master}"
    },
    "routingSubDomainType": {
      "value": "${dns_type_apps}"
    },
    "routingSubDomain": {
      "value": "${dns_apps}"
    },
    "virtualNetworkNewOrExisting": {
      "value": "new"
    },
    "virtualNetworkName": {
      "value": "ocpvnet"
    },
    "addressPrefixes": {
      "value": "10.0.0.0/14"
    },
    "masterSubnetName": {
      "value": "mastersubnet"
    },
    "masterSubnetPrefix": {
      "value": "10.1.0.0/16"
    },
    "infraSubnetName": {
      "value": "infrasubnet"
    },
    "infraSubnetPrefix": {
      "value": "10.2.0.0/16"
    },
    "nodeSubnetName": {
      "value": "nodesubnet"
    },
    "nodeSubnetPrefix": {
      "value": "10.3.0.0/16"
    },
    "masterClusterType": {
      "value": "public"
    },
    "masterPrivateClusterIp": {
      "value": "10.1.0.200"
    },
    "routerClusterType": {
      "value": "public"
    },
    "routerPrivateClusterIp": {
      "value": "10.2.0.200"
    },
    "routingCertType": {
      "value": "selfsigned"
    },
    "masterCertType": {
      "value": "selfsigned"
    },
    "proxySettings": {
      "value": "none"
    },
    "httpProxyEntry": {
      "value": "none"
    },
    "httpsProxyEntry": {
      "value": "none"
    },
    "noProxyEntry": {
      "value": "none"
    },
    "customHeaderImage": {
      "value": "none"
    }
  }
}
EOF

echo "Create stack with"
echo
echo "az group deployment create -g ${rg} --name ocp --template-uri https://raw.githubusercontent.com/duritong/openshift-container-platform/master/azuredeploy.json --parameters @./${rg}/ocp.json"
echo
echo "Delete stack with"
echo
echo "az group delete --name ${rg} --yes && az ad sp delete --id ${ad_id}"
