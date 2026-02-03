---
model: Claude Sonnet 4.5
description: 'This prompt is used to check the health status of pods in an Azure Kubernetes Service (AKS) cluster.'
---

# Check for Pod Health Issues

Check the health status of all pods in an Azure Kubernetes Service (AKS) cluster and identify any pods that are not in a 'Running' state. Provide a summary of the issues found and suggest possible remediation steps.

### Run these Commands

```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Output
The output a report in a readable format (e.g., plain text, JSON) that includes:
- Cluster Name
- Pod Name
- Pod Status
- Issues Found (if any)
- Suggested Remediation Steps

### Remediation Suggestions
For pods that are not in the 'Running' state, suggest possible remediation steps such as:
- Checking for resource constraints (CPU, memory)
- Reviewing pod logs for errors
- Scaling the cluster if resource limits are being hit
- Redeploying the pod if it is in a crash loop

### Note
Do not generate any scripts.
Do not directly fix the issues; only provide analysis and suggestions.