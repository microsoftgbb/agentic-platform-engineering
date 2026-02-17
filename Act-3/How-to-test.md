# How to test your setup

To port-forward into the ArgoCD UI

```bash
kubectl port-forward svc/argocd-server 8080:80 -n argocd
```

To force a deployment to go into degraded
```bash
kubectl patch deployment order-service -n default -p '{"spec":{"progressDeadlineSeconds":10}}'
```
