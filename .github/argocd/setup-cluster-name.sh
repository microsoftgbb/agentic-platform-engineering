#!/bin/bash
# Run this script once when ArgoCD is installed to set the cluster name
# Usage: ./setup-cluster-name.sh

set -e

CLUSTER_NAME=$(kubectl config current-context)

echo "Setting cluster name in ArgoCD notifications: $CLUSTER_NAME"

# Update the cluster-name in the argocd-notifications-cm ConfigMap
kubectl patch configmap argocd-notifications-cm -n argocd \
  -p "{\"data\":{\"cluster-name\":\"$CLUSTER_NAME\"}}"

# Restart the notifications controller to pick up the change
kubectl rollout restart deployment argocd-notifications-controller -n argocd

echo "✓ Cluster name configured: $CLUSTER_NAME"
echo ""
echo "ArgoCD notifications will now use cluster name: $CLUSTER_NAME"
