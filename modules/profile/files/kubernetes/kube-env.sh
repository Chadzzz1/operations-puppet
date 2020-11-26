#!/bin/bash
# function helpers to set and manage kubernetes env variables

# Set a k8s environment for your shell. This will allow correct usage of
# kubectl and helm/helmfile
kube_env() {
    if [[ "$1" == "admin" ]]; then
        TILLER_NAMESPACE="kube-system"
    else
        TILLER_NAMESPACE=$1
    fi
    K8S_CLUSTER=$2
    KUBECONFIG="/etc/kubernetes/${1}-${K8S_CLUSTER}.config"
    if [ ! -f "$KUBECONFIG" ]; then
        echo "Could not find a configuration for ${1}/${K8S_CLUSTER}"
        return 1
    fi
    export TILLER_NAMESPACE K8S_CLUSTER KUBECONFIG
}

# Clear your current kubernetes-related variables
kube_env_clear() {
    unset TILLER_NAMESPACE K8S_CLUSTER KUBECONFIG
}


# Add this function to your PS1 to add the currently configured
# k8s cluster to your prompt.
__kube_env_ps1() {
    if [ -z "$K8S_CLUSTER" ] || [ -z "$TILLER_NAMESPACE" ]; then
        return
    fi
    echo "<${TILLER_NAMESPACE}/${K8S_CLUSTER}>"
}


# HELM_HOME is the same for all users
export HELM_HOME="/etc/helm"
# Helm3 variables (we can share the same config home as filenames differ)
export HELM_CONFIG_HOME="/etc/helm"
# This contains helm plugins
export HELM_DATA_HOME="/usr/share/helm"
# This contains repository cache and plugin cache (which we don't use)
export HELM_CACHE_HOME="/var/cache/helm"
