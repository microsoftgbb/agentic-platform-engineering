#!/bin/bash
# Run this script once when ArgoCD is installed to set the cluster name and resource group
# Usage: ./setup-cluster-name.sh

set -e

CLUSTER_NAME=$(kubectl config current-context)
RESOURCE_GROUP=$(kubectl get nodes -o jsonpath='{.items[0].metadata.labels.kubernetes\.azure\.com/network-resourcegroup}')

echo "Setting cluster name in ArgoCD notifications: $CLUSTER_NAME"
echo "Setting resource group in ArgoCD notifications: $RESOURCE_GROUP"

# Update the cluster-name and resource-group in the argocd-notifications-cm ConfigMap
kubectl patch configmap argocd-notifications-cm -n argocd \
  -p "{\"data\":{\"cluster-name\":\"$CLUSTER_NAME\",\"resource-group\":\"$RESOURCE_GROUP\"}}"

# Restart the notifications controller to pick up the change
kubectl rollout restart deployment argocd-notifications-controller -n argocd

echo "✓ Cluster name configured: $CLUSTER_NAME"
echo "✓ Resource group configured: $RESOURCE_GROUP"
echo ""
echo "ArgoCD notifications will now use cluster name: $CLUSTER_NAME and resource group: $RESOURCE_GROUP"
