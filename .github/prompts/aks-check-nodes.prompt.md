---
model: Claude Sonnet 4
description: 'This prompt is used to check the health status of nodes in an Azure Kubernetes Service (AKS) cluster.'
---

# Check for AKS Nodes Health Issues

Check the health status of all nodes in an Azure Kubernetes Service (AKS) cluster and identify any nodes that are not in a 'Ready' state. Provide a summary of the issues found and suggest possible remediation steps.

### Run these Commands

```bash
kubectl get nodes
kubectl describe node <node-name>
kubectl top nodes
kubectl cluster-info
```


### Output
The output a report in a readable format (e.g., plain text, JSON) that includes:
- Cluster Name
- Node Name
- Node Status
- Issues Found (if any)
- Suggested Remediation Steps

### Remediation Suggestions
For nodes that are not in the 'Ready' state, suggest possible remediation steps such as:
- Checking for resource constraints (CPU, memory)
- Reviewing node logs for errors
- Scaling the cluster if resource limits are being hit
- Contacting Azure support if the issue persists

### Note
Ensure that you have the necessary permissions to access the AKS clusters and perform the required operations.
Do not generate any scripts.