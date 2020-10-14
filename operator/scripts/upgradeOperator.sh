#!/bin/bash
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
# CUR_DIR set to full path to scripts folder
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function show_help {
    echo -e "\nUsage: upgradeOperator.sh -i operator_image [-p 'secret_name']\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -i  Operator image name"
    echo "      For example: cp.icr.io/cp/icp4a-operator:20.0.3 or registry_url/icp4a-operator:version"
    echo "  -p  Optional: Pull secret to use to connect to the registry"
    echo "  -a  Accept IBM license"
}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:p:a:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        i)  IMAGEREGISTRY=$OPTARG
            ;;
        p)  PULLSECRET=$OPTARG
            ;;
        a)  LICENSE_ACCEPTED=$OPTARG
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

[ -f ${CUR_DIR}/../upgradeOperator.yaml ] && rm ${CUR_DIR}/../upgradeOperator.yaml
cp ${CUR_DIR}/../descriptors/operator.yaml ${CUR_DIR}/../upgradeOperator.yaml

# Show license file
function readLicense() {
    echo -e "\033[32mYou need to read the International Program License Agreement before start\033[0m"
    sleep 3
    more LICENSE
}

# Get user's input on whether accept the license
function userInput() {
    echo -e "\033[32mDo you accept the International Program License?(y/n)\033[0m"
    read -e choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        LICENSE_ACCEPTED=accept
    elif [[ "$choice" == "n" || "$choice" == "N" ]]; then
        echo -e "\033[31mScript will exit ...\033[0m"
        sleep 2
        exit 0
    else
        echo -e "\033[31mUnexpected input\033[0m"
        userInput
    fi
}

if [[ $LICENSE_ACCEPTED != "accept" ]]; then
    readLicense
    userInput
fi

if [[ $LICENSE_ACCEPTED == "accept" ]]; then
    sed -e '/dba_license/{n;s/value:/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
    sed -e '/baw_license/{n;s/value:/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
    sed -e '/fncm_license/{n;s/value:/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
    sed -e '/ier_license/{n;s/value:/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
    
    if [ ! -z ${IMAGEREGISTRY} ]; then
    # Change the location of the image
    echo "Using the operator image name: $IMAGEREGISTRY"
    sed -e "s|image: .*|image: \"$IMAGEREGISTRY\" |g" ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
    fi

    # Change the pullSecrets if needed
    if [ ! -z ${PULLSECRET} ]; then
        echo "Setting pullSecrets to $PULLSECRET"
        sed -e "s|admin.registrykey|$PULLSECRET|g" ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
    else
        sed -e '/imagePullSecrets:/{N;d;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
    fi

    kubectl apply -f ${CUR_DIR}/../descriptors/service_account.yaml --validate=false
    kubectl apply -f ${CUR_DIR}/../descriptors/role.yaml --validate=false
    kubectl apply -f ${CUR_DIR}/../descriptors/role_binding.yaml --validate=false
    kubectl apply -f ${CUR_DIR}/../upgradeOperator.yaml --validate=false
    echo -e "\033[32mAll descriptors have been successfully applied. Monitor the pod status with 'kubectl get pods -w'.\033[0m"
else
  echo -e "\033[31mIBM software license unexpected error, there is no LICENSE_ACCEPTED variable in setProperties.sh\033[0m"
  exit 1
fi
