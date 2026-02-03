# ArgoCD GitHub Issue Creation Setup Guide

This guide sets up automatic GitHub issue creation when ArgoCD deployments fail.

## Architecture

```
ArgoCD Deployment Failure → ArgoCD Notifications → GitHub Repository Dispatch → GitHub Actions → Create Issue
```

## Files Created

1. `.github/argocd/argocd-notifications-config.yaml` - ArgoCD notification configuration
2. `.github/workflows/argocd-deployment-failure.yml` - GitHub Actions workflow

## Setup Steps

### 1. Create a GitHub Personal Access Token

1. Go to https://github.com/settings/tokens?type=beta
2. Click "Generate new token" → "Fine-grained personal access token"
3. Configure:
   - **Name:** `ArgoCD Notifications`
   - **Repository access:** Select your target repository
   - **Permissions:**
     - Repository permissions → Contents: Read-only
     - Repository permissions → Metadata: Read-only (automatically selected)
     - Repository permissions → Actions: Read and write (for repository_dispatch)
     - Repository permissions → Issues: Read and write
4. Click "Generate token" and copy it (starts with `github_pat_...`)

### 2. Add Secrets to Kubernetes

```bash
# Add your GitHub token to ArgoCD notifications
kubectl patch secret argocd-notifications-secret -n argocd -p='{"stringData":{"github-token":"YOUR_GITHUB_TOKEN_HERE"}}'
```

### 3. Configure Cluster Name Context

Set the cluster name that will be included in notifications:

```bash
# Get current cluster context name
CLUSTER_NAME=$(kubectl config current-context)

# Add the context to the ConfigMap
kubectl patch configmap argocd-notifications-cm -n argocd --type=merge -p "{\"data\":{\"context\":\"clusterName: ${CLUSTER_NAME}\n\"}}"
```

The cluster name will be accessible in notification templates as `{{.context.clusterName}}`.

### 4. Set Environment Variables in Config

Configure the webhook service and notification template:

```bash
# Replace with your values
export GITHUB_OWNER="your-github-username-or-org"
export GITHUB_REPO="your-repo-name"

# Add the GitHub webhook service configuration
kubectl patch configmap argocd-notifications-cm -n argocd --type=merge -p "{\"data\":{\"service.webhook.github-webhook\":\"url: https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/dispatches\nheaders:\n- name: Accept\n  value: application/vnd.github+json\n- name: Authorization\n  value: Bearer \\\$github-token\n- name: X-GitHub-Api-Version\n  value: \\\"2022-11-28\\\"\n- name: Content-Type\n  value: application/json\n\"}}"

# Add the webhook template (note: use single file method below if patch causes issues)
```

**Alternative: Apply complete configuration from file**

If you encounter template parsing errors with patches, create and apply a complete configuration file:

```bash
# Create the complete ConfigMap file
cat <<'EOF' > /tmp/argocd-notifications-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  context: |
    clusterName: YOUR_CLUSTER_NAME
  service.webhook.github-webhook: |
    url: https://api.github.com/repos/YOUR_OWNER/YOUR_REPO/dispatches
    headers:
    - name: Accept
      value: application/vnd.github+json
    - name: Authorization
      value: Bearer $github-token
    - name: X-GitHub-Api-Version
      value: "2022-11-28"
    - name: Content-Type
      value: application/json
  template.sync-failed-webhook: |
    webhook:
      github-webhook:
        method: POST
        body: |
          {
            "event_type": "argocd-sync-failed",
            "client_payload": {
              "app_name": "{{.app.metadata.name}}",
              "health_status": "{{.app.status.health.status}}",
              "sync_status": "{{.app.status.sync.status}}",
              "message": "{{.app.status.operationState.message}}",
              "revision": "{{.app.status.sync.revision}}",
              "repo_url": "{{.app.spec.source.repoURL}}",
              "cluster": "{{.context.clusterName}}",
              "namespace": "{{.app.spec.destination.namespace}}",
              "timestamp": "{{.app.status.operationState.finishedAt}}",
              "resources": {{toJson .app.status.resources}}
            }
          }
  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [sync-failed-webhook]
  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [sync-failed-webhook]
EOF

# Edit the file to replace YOUR_CLUSTER_NAME, YOUR_OWNER, YOUR_REPO
vi /tmp/argocd-notifications-cm.yaml

# Apply using replace --force to avoid kubectl apply annotation issues
kubectl replace --force -f /tmp/argocd-notifications-cm.yaml
```

**Important notes:**
- Use `kubectl patch` for incremental changes to preserve existing configuration
- Use `kubectl replace --force` only if applying a complete configuration file, as it will overwrite the entire ConfigMap
- The `kubectl apply` command can create problematic annotations that cause template parsing errors - avoid it for this ConfigMap
- Use camelCase variable names in the context block (not hyphenated) to avoid template parsing errors

### 5. Commit and push the workflow

```bash
cd /home/dcasati/src/agentic-platform-engineering

# Add the files
git add .github/workflows/argocd-deployment-failure.yml
git add .github/argocd/argocd-notifications-config.yaml

# Commit
git commit -m "Add ArgoCD deployment failure notification workflow"

# Push
git push
```

### 6. Enable Notifications on Your ArgoCD Applications

Add annotations to your ArgoCD Application manifests:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  annotations:
    notifications.argoproj.io/subscribe.on-sync-failed.github-webhook: ""
    notifications.argoproj.io/subscribe.on-health-degraded.github-webhook: ""
spec:
  # ... rest of your application spec
```

Or use the ArgoCD CLI:

```bash
# Subscribe to sync failed notifications
argocd app patch my-app --patch='{"metadata":{"annotations":{"notifications.argoproj.io/subscribe.on-sync-failed.github-webhook":""}}}'

# Subscribe to health degraded notifications
argocd app patch my-app --patch='{"metadata":{"annotations":{"notifications.argoproj.io/subscribe.on-health-degraded.github-webhook":""}}}'
```

## Testing

1. ArgoCD detects sync failure or degraded health
2. ArgoCD Notifications sends webhook to GitHub repository_dispatch
3. GitHub Actions workflow is triggered
4. Workflow checks for existing open issues for the same app
   - If exists: Adds comment with new failure details
   - If not: Creates new issue with full details
5. Issue includes:
   - Error message
   - Revision/commit that failed
   - Health and sync status
   - Recommended remediation steps
   - Links to ArgoCD UI and source repository

## Security Features

- ✅ Fine-grained GitHub token with minimal permissions (Contents, Actions, Issues)
- ✅ Token stored in Kubernetes secret (not in code)
- ✅ Token authentication protects GitHub API endpoint
- ✅ Automatic duplicate issue detection
- ✅ Labels for easy filtering: `argocd-deployment-failure`, `automated`, `bug`

## Troubleshooting

### Notifications not being sent:

```bash
# Check notifications controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller

# Verify the secret has the GitHub token
kubectl get secret argocd-notifications-secret -n argocd -o yaml

# Verify the ConfigMap is applied
kubectl get configmap argocd-notifications-cm -n argocd -o yaml
```

### Issues not being created:

1. Check GitHub Actions workflow runs in your repository
2. Verify the repository_dispatch event type matches: `argocd-sync-failed`
3. Check workflow logs for errors
4. Verify token permissions include "Actions: Read and write" and "Issues: Read and write"

## Next Steps

After completing the setup:

1. Test with a known-good application first
2. Gradually enable on critical applications
3. Monitor the issue tracker for patterns
4. Customize the issue template as needed
5. Consider adding auto-close logic when apps recover
