#!/bin/bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# --- CONFIG ---

NAMESPACE="sre"
DEPLOYMENT_NAME="swype-app"
POD_LABEL="app=${DEPLOYMENT_NAME}"
MAX_POD_RESTARTS=3
CHECK_INTERVAL=60

# --- FUNCTIONS ---

# Helper function to write messages with timestamp
info_msg(){
    local _timestamp
    _timestamp=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
    echo "[${_timestamp}] ${*}"
}

# Wrapper function for sleep
pause(){
    info_msg "Sleeping ${CHECK_INTERVAL} seconds..."
    sleep  ${CHECK_INTERVAL}
}

# Function to get the total count of pod restarts
total_pod_restarts(){
    local _namespace _label _total
     _namespace=${1}
     _label=${2}

    _total=$(kubectl get pods -n ${_namespace} -l ${_label} -o jsonpath='{.items[*].status.containerStatuses[*].restartCountt}')
    
    if [ -z "$_total" ]; then
        echo "0"
    else
        echo "${_total}"
    fi
}

scale_deployment_to_zero(){
    local _namespace _deployment_name 
     _namespace=${1}
     _deployment_name=${2}

    info_msg "Number of restarts exceeded the maximum allowed. Scaling down the deployment ${_deployment_name} to zero."        
    kubectl scale deployment ${_deployment_name} -n ${_namespace} --replicas=0
    info_msg "Scale down completed."
}

# -----------------------------------------------------------
# Main function (overall business logic is centralized below)
# -----------------------------------------------------------
main(){
    local _pod_restarts

    while true; do
        _pod_restarts=$(total_pod_restarts ${NAMESPACE} ${POD_LABEL})
        info_msg "Current number of restarts for '${DEPLOYMENT_NAME}' deployment: ${_pod_restarts}"
    
        if [[ ${_pod_restarts} -gt $MAX_POD_RESTARTS ]]; then
            scale_deployment_to_zero ${NAMESPACE} ${DEPLOYMENT_NAME}
            break
        fi
        pause 
    done
}
# ------------------------------------
# SCRIPT STARTS HERE
# ------------------------------------
main
