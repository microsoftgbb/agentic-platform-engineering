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

### 3. Set Environment Variables in Config

Edit the ArgoCD notifications ConfigMap to set your GitHub owner and repo:

```bash
# Replace with your values
export GITHUB_OWNER="your-github-username-or-org"
export GITHUB_REPO="your-repo-name"

# Update the webhook URL
kubectl patch configmap argocd-notifications-cm -n argocd --type=merge -p="{\"data\":{\"service.webhook.github-webhook\":\"url: https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/dispatches\nheaders:\n- name: Accept\n  value: application/vnd.github+json\n- name: Authorization\n  value: Bearer \$github-token\n- name: X-GitHub-Api-Version\n  value: '2022-11-28'\n- name: Content-Type\n  value: application/json\"}}"
```

Or manually edit and apply the config file:

```bash
# Edit the file
vi .github/argocd/argocd-notifications-config.yaml

# Replace $GITHUB_OWNER and $GITHUB_REPO with your actual values

# Apply it
kubectl apply -f .github/argocd/argocd-notifications-config.yaml
```

### 4. Add Secret to GitHub Repository

1. Go to your GitHub repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `ARGOCD_WEBHOOK_SECRET`
4. Value: `udd2UzDVgpRyrIw9XBW8YiNuLO9aCV/4eKFe/wlr4hU=`
5. Click "Add secret"

### 5. Commit and Push the Workflow

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

### Test the notification system:

1. Deploy a broken application to trigger a failure
2. Check ArgoCD notifications controller logs:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller -f
   ```
3. Verify the webhook was sent to GitHub
4. Check GitHub Actions workflow run
5. Verify issue was created in your repository

### Manual test without breaking a deployment:

```bash
# Send a test notification
kubectl exec -n argocd deployment/argocd-notifications-controller -- \
  argocd-notifications trigger on-sync-failed \
  --app my-app
```

## What Happens on Deployment Failure

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

- ✅ Fine-grained GitHub token with minimal permissions
- ✅ Token stored in Kubernetes secret (not in code)
- ✅ Webhook secret for signature verification
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

## Webhook Secret

**Important:** The webhook secret is:
```
udd2UzDVgpRyrIw9XBW8YiNuLO9aCV/4eKFe/wlr4hU=
```

This must be stored in:
- ✅ Kubernetes: `argocd-notifications-secret` (already done)
- ⚠️ GitHub: Repository secrets as `ARGOCD_WEBHOOK_SECRET` (you need to do this)

## Next Steps

After completing the setup:

1. Test with a known-good application first
2. Gradually enable on critical applications
3. Monitor the issue tracker for patterns
4. Customize the issue template as needed
5. Consider adding auto-close logic when apps recover
