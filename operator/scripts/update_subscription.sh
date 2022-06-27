#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

PROGRAM_NAME=$(basename "$0")
SKIP_CONFIRM=0

CS_CATALOG="opencloud-operators"
BTS_CATALOG="bts-operator"
DB2U_CATALOG="ibm-db2uoperator-catalog"
POSTGRES_CATALOG="cloud-native-postgresql-catalog"
CS_CATALOG_LIST="${CS_CATALOG} ${BTS_CATALOG} ${DB2U_CATALOG} ${POSTGRES_CATALOG}"
CP4BA_CATALOG="ibm-cp4a-operator-catalog"
IAF_CATALOG="ibm-cp-automation-foundation-catalog"
IAF_CORE_CATALOG="ibm-automation-foundation-core-catalog"
CS_SUBS="operand-deployment-lifecycle-manager-app ibm-namespace-scope-operator ibm-events-operator ibm-common-service-operator 
    ibm-cert-manager-operator ibm-commonui-operator ibm-iam-operator ibm-ingress-nginx-operator ibm-licensing-operator 
    ibm-management-ingress-operator ibm-mongodb-operator ibm-platform-api-operator ibm-zen-operator ibm-crossplane-operator-app 
    ibm-crossplane-provider-kubernetes-operator-app"

###############################################################################
# Script usage info
###############################################################################
function usage() {
    cat << EOF
    
Prerequisites:
   1. Have OC CLI installed and Logged in to your cluster.
   2. CatalogSource for pinned catalog was applied to the cluster in openshift-marketplace.
Usage: ${PROGRAM_NAME} [-n NAMESPACE] [-s]
  -n    string      specify cp4ba namespace, 'openshift-operators' if all-namespace
  -s                skip confirmation
EOF
}

###############################################################################
# Command line interface
###############################################################################
function cli() {
    while getopts "h?sn:" opt; do
        case "$opt" in
        n)
            NAMESPACE=${OPTARG}
            ;;
        s)
            SKIP_CONFIRM=1
            ;;
        h|\?)
            usage
            exit 0
            ;;
        :)  
            echo "Invalid option: -${OPTARG} requires an argument"
            usage
            exit 1
            ;;
        esac
    done
}

###############################################################################
# Script requirement checks
###############################################################################
function prereq_check() {
    if ! [ -x "$(command -v oc)" ]; then
        echo 'Error: oc cli is not installed.' >&2
        exit 1
    fi
    oc get pod >/dev/null 2>&1
    if [ $? -gt 0 ]; then
        echo -e "oc login required" >&2
        exit 1
    fi
    if [ -z "${NAMESPACE}" ]; then
        CP4BA_SUB=$(oc get sub -A | grep "ibm-cp4a-operator" | grep -v "wfps")
        CP4BA_SUB_COUNT=$(oc get sub -A | grep "ibm-cp4a-operator" | grep -v -c "wfps")
        if [ "${CP4BA_SUB_COUNT}" -le "0" ]; then
            echo -e "Error: CP4BA subscription not found in any namespace." >&2
            exit 1
        elif [ "${CP4BA_SUB_COUNT}" -eq "1" ]; then
            NAMESPACE=$(echo "${CP4BA_SUB}" | awk '{print $1}')
        else
            echo -e "Error: More than one project with CP4BA subscription found, please specify namespace using '-n'" >&2
            exit 1
        fi
    else
        CP4BA_SUB_COUNT=$(oc get sub -n "${NAMESPACE}" | grep "ibm-cp4a-operator" | grep -v -c "wfps")
    fi
    if ! [[ ${NAMESPACE} =~ ^[0-9a-z][-0-9a-zA-Z]{2,62}$ ]]; then
        echo -e "Error: Invalid namespace input '${NAMESPACE}'." >&2
        exit 1
    elif [[ ${NAMESPACE} == "default" ]]; then
        echo -e "Error: CP4BA should not be deploy on default namespace '${NAMESPACE}'." >&2
        exit 1
    elif [[ ${NAMESPACE} == "openshift-"* ]] && [[ ${NAMESPACE} != "openshift-operators" ]]; then
        echo -e "Error: CP4BA should not be deploy on openshift namespace '${NAMESPACE}'." >&2
        exit 1
    elif [[ "${CP4BA_SUB_COUNT}" -eq "0" ]]; then
        echo -e "Error: CP4BA subscription not found in provided namespace: '${NAMESPACE}'." >&2
        exit 1
    fi
    if [ -z "$(oc get project "${NAMESPACE}" 2>/dev/null)" ]; then
        echo -e "Error: Project ${NAMESPACE} does not exist. Specify an existing project where CP4BA is installed." >&2
        exit 1
    fi
    echo -e "CP4BA operators namespace: ${NAMESPACE}"

    local opencloud_check
    for catalog in ${CS_CATALOG_LIST}; do
        if ! [ "$(oc get catalogsource "${catalog}" -n openshift-marketplace --ignore-not-found)" ]; then 
            echo -e "Error: check your catalogsource, \"${catalog}\" is missing."
            exit 1;
        fi
        opencloud_check=$(oc get catalogsource "${catalog}" -n openshift-marketplace -o yaml | grep -c 'bedrock_catalogsource_priority:')
        if [ "${opencloud_check}" -lt 1 ]; then
            echo -e "Error: CatalogSource \"${catalog}\" missing annotation \"bedrock_catalogsource_priority: '1'\""
        exit 1
        fi
    done
}

###############################################################################
# Get subscription name
# Arguments:
#   filter for grep command on getting sub
# Outputs:
#   name of subscription(s)
###############################################################################
function get_sub_name() {
    local sub_list
    local sub_match
    local sub_match_count
    sub_list=$(oc get sub --no-headers | awk '{print $1}')
    sub_match=$(echo "${sub_list}" | grep -E "$1")
    sub_match_count=$(echo "${sub_list}" | grep -E -c "$1")
    if [ "${sub_match_count}" -eq 1 ]; then
        echo "${sub_match}"
    elif [ "${sub_match_count}" -gt 1 ]; then
        sub_match=$(echo "${sub_match}" | tr '\n' ' ')
        echo "${sub_match}"
    else
        echo "SUB_DNE"
    fi
}

###############################################################################
# Patch the source of subscription
# Arguments:
#   name of subscription
#   source to patch
###############################################################################
function patch_sub() {
    local source
    if oc get sub "$1" --no-headers &> /dev/null ; then
        source=$(oc get sub "$1" --no-headers | awk '{print $3}')
        if [ "${source}" == "$2" ]; then return 0; fi
        while :; do
            oc patch sub "$1" --type=json -p '[{"op": "replace", "path": "/spec/source", "value": "'"$2"'"}]'
            sleep 1
            source=$(oc get sub "$1" --no-headers | awk '{print $3}') 
            if [ "${source}" == "$2" ]; then
                break
            fi
        done
    fi
}

###############################################################################
# Patch all subscription in ibm-common-services namespace
###############################################################################
function patch_cs_sub() {
    # for subs uses opencloud-operators in ibm-common-services
    for sub in ${CS_SUBS}; do
        patch_sub "${sub}" "${CS_CATALOG}"
    done

    # for ibm-bts-operator sub in ibm-common-services
    BTS_SUB=$(get_sub_name "bts-operator")
    patch_sub "${BTS_SUB}" "${BTS_CATALOG}"
    
    # for cloud-native-postgresql sub in ibm-common-services
    POSTGRES_SUB=$(get_sub_name "cloud-native-postgresql")
    patch_sub "${POSTGRES_SUB}" "${POSTGRES_CATALOG}"
    
    # for ibm-db2u-operator sub in ibm-common-services
    DB2U_SUB=$(get_sub_name "db2u-operator")
    patch_sub "${DB2U_SUB}" "${DB2U_CATALOG}" 
}

###############################################################################
# Patch all subscription in cp4ba namespace
###############################################################################
function patch_ns_sub() {
    # for iaf core sub in cp4ba namespace
    IAF_CORE_SUB=$(get_sub_name "ibm-automation-core")
    patch_sub "${IAF_CORE_SUB}" "${IAF_CORE_CATALOG}"
    
    # for iaf subs in cp4ba namespace
    IAF_SUBS=$(get_sub_name "ibm-automation-[^c]")
    for sub in ${IAF_SUBS}; do
        patch_sub "${sub}" "${IAF_CATALOG}"
    done

    # for ibm-common-service-operator sub in cp4ba namespace
    CS_SUB=$(get_sub_name "ibm-common-service-operator")
    patch_sub "${CS_SUB}" "${CS_CATALOG}"

    # for cp4a subs in cp4ba namespace
    CP4BA_SUBS=$(get_sub_name "ibm-cp4a-")
    for sub in ${CP4BA_SUBS}; do
        patch_sub "${sub}" "${CP4BA_CATALOG}"
    done
}

### MAIN ###
cli "$@"
prereq_check

echo
echo "All prereq checks passed!"
echo

if [[ "${SKIP_CONFIRM}" -eq "0" ]]; then
    echo -e "This script will update subscription for 'IBM Cloud Pak for Business Autmation' operator and it's dependencies, 
        including 'IBM Automation Foundation' and 'IBM Common Services'."
    echo -e "Use -s argument to skip this confirmation, -h for help."
    read -p "Press 'Y' to continue: " -n 1 -r
    echo
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 0
    fi
    echo -e "OK. Continuing...."
    echo
fi

oc project ibm-common-services >/dev/null
echo -e "Recreating operandregistry common-service..."
oc delete opreg common-service -n ibm-common-services 
oc delete pod "$(oc get pod -n ibm-common-services | grep ibm-common-service-operator | awk '{print $1}')" -n ibm-common-services
sleep 3
while :; do
    if [ "$(oc get opreg -n ibm-common-services common-service --ignore-not-found)" ]; then
        break
    else
        echo "Waiting for operandregistry 'common-service' to be recreated..."
        sleep 10
    fi
done

echo -e "Updating subscription in 'ibm-common-services' namespace"
patch_cs_sub

oc project "${NAMESPACE}" >/dev/null
echo -e "Updating subscription in '${NAMESPACE}' namespace..."
patch_ns_sub

echo -e "Validating Subscriptions..."
sleep 20
oc project ibm-common-services >/dev/null
while :; do
    if [ "$(oc get sub --no-headers | awk '{print $3}' | grep -c 'ibm-operator-catalog')" -ge 1 ]; then
        patch_cs_sub
        sleep 2
    else
        break
    fi
done
oc project "${NAMESPACE}" >/dev/null
while :; do
    if [ "$(oc get sub --no-headers | awk '{print $3}' | grep -c 'ibm-operator-catalog')" -ge 1 ]; then
        patch_ns_sub
        sleep 2
    else
        break
    fi
done

echo -e "Subscriptions Update Completed!"
