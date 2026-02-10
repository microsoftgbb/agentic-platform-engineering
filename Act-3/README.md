# Act 3: Kubernetes Operations Don't Scale Linearly

> **Workshop Goal:** Build event-driven agent workflows that automatically detect deployment failures, create actionable issues, and invoke specialized agents to diagnose and remediate cluster problems.

---

## The Scene: The 3am Page

Your platform team built a great Kubernetes platform. ArgoCD handles GitOps deployments. Monitoring is in place. Everything looks good on paper.

Then the PagerDuty alert hits at 3am: **"Deployment failed in production."**

Here's what happens next:
- Someone wakes up, bleary-eyed, and opens a laptop
- They try to remember which cluster, which namespace, which app
- They run `kubectl get pods` and see `CrashLoopBackOff`
- They dig through logs, events, and maybe a dozen StackOverflow tabs
- Two hours later, they find a typo in the resource limits
- They fix it, go back to bed, and forget to document what happened

**The next incident?** Same dance. Different engineer. Same tribal knowledge gap.

**No blame. No shame. You're only human.**

The problem isn't your Kubernetes skills. The problem is that **operational expertise doesn't scale linearly**—your senior engineers can't be awake 24/7, and your runbooks can't anticipate every failure mode.

---

## The Insight: Event-Driven Agents as Operational Partners

What if the moment a deployment failed, an automated system could:
1. **Detect** the failure in real-time
2. **Capture** all relevant context (cluster, namespace, error messages, resource states)
3. **Create** a structured GitHub Issue with troubleshooting commands
4. **Invoke** a specialized agent to diagnose and propose fixes
5. **Open** a PR with the remediation—ready for human review

| Human Reality | Agent Solution |
|---------------|----------------|
| Woken up at 3am, context-switching from sleep | Agent is always awake, immediately engaged |
| Forgets which kubectl commands to run under stress | Agent follows systematic diagnostic workflow every time |
| Tribal knowledge: "Oh, this looks like the rate-limiter issue from last month" | Agent correlates symptoms with documented patterns |
| Fixes the issue, forgets to document | Agent creates PR with explanation and audit trail |
| Root cause analysis happens "when we have time" (never) | Agent documents diagnosis in real-time |

**The pattern:** Don't wait for humans to trigger diagnostics. Let events trigger agents, and let agents surface structured findings for human decision-making.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          Event-Driven Agent Workflow                          │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐    Webhook     ┌───────────────────┐    Creates    ┌──────┐│
│  │   ArgoCD    │ ─────────────▶ │ argocd-deployment │ ────────────▶ │GitHub││
│  │ (detects    │   repository   │ -failure.yml      │    Issue      │Issue ││
│  │  failure)   │   _dispatch    │ (Workflow #1)     │   (labeled)   │      ││
│  └─────────────┘                └───────────────────┘               └──┬───┘│
│                                                                        │    │
│                                         Label: "cluster-doctor"        │    │
│                                                                        ▼    │
│  ┌─────────────┐    Reads       ┌───────────────────┐    Uses    ┌────────┐│
│  │   Cluster   │ ◀───────────── │ copilot.trigger-  │ ─────────▶ │ GitHub ││
│  │   Doctor    │    Agent       │ cluster-doctor.yml│   Copilot  │MCP APIs││
│  │   Agent     │    File        │ (Workflow #2)     │    CLI     │        ││
│  └─────────────┘                └───────────────────┘            └────────┘│
│        │                                                              │     │
│        │                                                              │     │
│        ▼                                                              ▼     │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  Agent adds issue comment with diagnosis + creates PR with fix         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Crawl — The Cluster Doctor Agent

### The Concept

Before wiring up automation, let's understand the agent that does the actual work. The **Cluster Doctor** is a custom GitHub Copilot agent that encodes senior Kubernetes administrator expertise.

### Agent Definition

The agent is defined at [.github/agents/cluster-doctor.agent.md](../.github/agents/cluster-doctor.agent.md):

```markdown
---
name: Cluster Doctor
description: "An expert Kubernetes administrator agent specializing in 
cluster troubleshooting, networking, NetworkPolicy, security posture, 
admission controllers, and GitOps workflows."
---

## Persona

- Role: Senior Kubernetes Administrator, SRE, and GitOps engineer.
- Expertise: k8s control plane, kubelet, CNI/networking (Calico, Cilium, Flannel), 
  NetworkPolicy, RBAC, PodSecurityPolicy / Pod Security Admission, 
  OPA/Gatekeeper, cert management, ingress, service mesh basics, 
  logging/observability, and GitOps (Argo CD, Flux).

## Goals

- Assess provided information about a failing cluster deployment or runtime issue.
- Independently confirm or refute user/Issue supplied assertions by collecting evidence.
- Triage and produce a prioritized diagnosis and remediation plan.
- Produce safe, reversible remediation steps and GitOps PRs to fix manifests.
```

### Key Agent Behaviors

The Cluster Doctor agent follows a deliberate workflow:

| Phase | What the Agent Does |
|-------|---------------------|
| **1. Collect** | Automatically retrieve context using provided credentials—kubeconfig, logging endpoints, Git repo access |
| **2. Verify** | Execute read-only diagnostics (`kubectl get events`, `describe pod`, CNI probes) |
| **3. Diagnose** | Correlate collected data to identify probable root causes, ranked by confidence |
| **4. Triage** | Prioritize issues by impact and urgency |
| **5. Remediate** | Create GitOps PRs with diffs, or propose scoped in-cluster changes |

### Safety First

The agent includes critical safety constraints:

```markdown
## Permissions & Safety

- The agent must never attempt destructive changes unless explicitly authorized.
- Cluster Identity Certainty (REQUIRED): Before any write action, the agent must 
  confirm the target cluster matches the incident using at least two independent 
  signals (API server URL, TLS certificate fingerprint, cluster UID).
- If signals don't match, the agent aborts non-read-only actions and marks the 
  incident as "cluster-identity uncertain."
- Prefer GitOps PRs over direct `kubectl apply` unless explicit authorization exists.
```

**Why this matters:** An agent with cluster credentials is powerful—and dangerous. These guardrails ensure the agent can't accidentally modify the wrong cluster or make destructive changes without proper authorization.

### Manual Usage (Crawl Phase)

During the crawl phase, you invoke the Cluster Doctor manually when you need help:

```bash
# In VS Code with GitHub Copilot Chat, assuming the agent is loaded
@cluster-doctor My deployment webapp in namespace prod has CrashLoopBackOff. 
I see "back-off restarting failed container". Help me diagnose.
```

The agent will:
1. Ask for (or automatically collect) diagnostic information
2. Walk through a systematic troubleshooting process
3. Provide specific remediation recommendations

---

## Phase 2: Walk — Automated Issue Creation from ArgoCD

### The Concept

Manual agent invocation is useful, but it still requires a human to notice the problem and ask for help. The next level: **automatic issue creation** when deployments fail.

ArgoCD has a notification system that can send webhooks when applications change state. We wire this to GitHub to create structured issues automatically.

### Workflow: ArgoCD Deployment Failure Handler

See the full workflow at [.github/workflows/argocd-deployment-failure.yml](../.github/workflows/argocd-deployment-failure.yml):

```yaml
name: ArgoCD Deployment Failure Handler

on:
  repository_dispatch:
    types: [argocd-sync-failed]

permissions:
  issues: write
  contents: read

jobs:
  create-issue:
    runs-on: ubuntu-latest
    
    steps:
      - name: Create GitHub Issue
        uses: actions/github-script@v7
        with:
          script: |
            const payload = context.payload.client_payload || {};
            const appName = payload.app_name || 'unknown';
            const clusterName = payload.cluster || 'in-cluster';
            const namespace = payload.namespace || 'default';
            // ... extract all relevant context
            
            const issueTitle = `ArgoCD Deployment Failed: ${appName}`;
            
            const issueBody = `## ArgoCD Deployment Failure
            
            **Application:** \`${appName}\`
            **Cluster:** \`${clusterName}\`
            **Namespace:** \`${namespace}\`
            
            ### Error Message
            \`\`\`
            ${message}
            \`\`\`
            
            ### Troubleshooting Commands
            \`\`\`bash
            kubectl get pods -n ${namespace}
            kubectl describe pods -n ${namespace}
            kubectl get events -n ${namespace} --sort-by='.lastTimestamp'
            \`\`\`
            `;
            
            // Check for existing open issue to avoid duplicates
            const existingIssues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'open',
              labels: 'argocd-deployment-failure',
              per_page: 100
            });
            
            // Create new issue or add comment to existing
            // ...
```

### What This Workflow Does

| Step | Purpose |
|------|---------|
| **Trigger:** `repository_dispatch` | ArgoCD sends a webhook when sync fails |
| **Extract context** | Pull app name, cluster, namespace, error message, resource states from the webhook payload |
| **Build structured issue** | Create a well-formatted issue with all diagnostic context |
| **Include troubleshooting commands** | Pre-populate kubectl commands specific to this failure |
| **Deduplicate** | If an issue already exists for this app, add a comment instead of creating duplicates |
| **Label** | Apply `argocd-deployment-failure`, `automated`, `bug` labels |

### ArgoCD Configuration

ArgoCD needs to be configured to send webhooks. See [SETUP.md](./SETUP.md) for complete instructions.

Key ArgoCD ConfigMap entries:

```yaml
# Webhook service definition
service.webhook.github-webhook: |
  url: https://api.github.com/repos/YOUR_OWNER/YOUR_REPO/dispatches
  headers:
  - name: Authorization
    value: Bearer $github-token

# Template for the webhook payload
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
            "resources": {{toJson .app.status.resources}}
          }
        }

# Triggers that invoke the webhook
trigger.on-health-degraded: |
  - when: app.status.health.status == 'Degraded'
    send: [sync-failed-webhook]

trigger.on-sync-failed: |
  - when: app.status.operationState.phase in ['Error', 'Failed']
    send: [sync-failed-webhook]
```

### The Result

When a deployment fails, you get:
- **Immediate visibility** — an issue appears in your repo within seconds
- **Full context** — cluster, namespace, error message, resource states all captured
- **Runnable commands** — copy-paste kubectl commands ready to execute
- **Audit trail** — every failure is documented, even if it self-heals

---

## Phase 3: Run — Agent-Triggered Automated Diagnosis

### The Concept

We have issues being created automatically. Now let's trigger the Cluster Doctor agent to analyze those issues and propose fixes—without human intervention to kick it off.

### Workflow: Trigger Cluster Doctor

See the full workflow at [.github/workflows/copilot.trigger-cluster-doctor.yml](../.github/workflows/copilot.trigger-cluster-doctor.yml):

```yaml
name: Trigger Cluster Doctor

on:
  workflow_dispatch:
  issues:
    types: [labeled]

jobs:
  run-cluster-doctor:
    if: github.event_name == 'workflow_dispatch' || github.event.label.name == 'cluster-doctor'
    runs-on: ubuntu-latest
    permissions:
      contents: write
      issues: write
      pull-requests: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: Install GitHub Copilot CLI
        run: |
          curl -fsSL https://gh.io/copilot-install | bash
                    
      - name: Analyze and delegate to Copilot
        env:
          GITHUB_MCP_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITHUB_TOKEN: ${{ secrets.COPILOT_CLI_TOKEN }}
        run: |
          export PROMPT="Use the GitHub MCP Server to analyze GitHub Issue 
            #${{ github.event.issue.number }} in repository ${{ github.repository }}. 
            Document findings as an issue comment, and create a PR for any fixes."
          
          copilot -p "$PROMPT" \
            --agent "cluster-doctor" \
            --additional-mcp-config @'.copilot/mcp-config.json' \
            --allow-all-tools
```

### How the Pieces Connect

1. **ArgoCD detects failure** → sends webhook to GitHub
2. **Workflow #1 (`argocd-deployment-failure.yml`)** → creates issue with context
3. **Human or automation adds `cluster-doctor` label to issue**
4. **Workflow #2 (`copilot.trigger-cluster-doctor.yml`)** → fires on label event
5. **Copilot CLI invokes Cluster Doctor agent** → reads issue, analyzes, proposes fix
6. **Agent uses GitHub MCP Server** → adds comment to issue, creates PR with remediation

### MCP Configuration

The workflow uses MCP (Model Context Protocol) servers to give the agent access to GitHub APIs and cluster diagnostics. See [.copilot/mcp-config.json](../.copilot/mcp-config.json):

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "tools": ["*"],
      "headers": {
        "Authorization": "Bearer ${GITHUB_MCP_TOKEN}"
      }
    },
    "aks-mcp": {
      "type": "http",
      "url": "http://localhost:8000/mcp",
      "tools": ["*"]
    }
  }
}
```

### Triggering Options

| Method | When to Use |
|--------|-------------|
| **Manual label** | Human reviews issue and decides to invoke agent |
| **Auto-label** | Modify the ArgoCD workflow to add `cluster-doctor` label on creation |
| **`workflow_dispatch`** | Manual trigger for testing or ad-hoc analysis |

> [!NOTE]
> **Automatic vs. Human-Triggered**
> 
> You might choose to NOT auto-trigger the Cluster Doctor on every failure. Reasons:
> - Cost control (Copilot PRU consumption)
> - Some failures are transient and self-heal
> - You want human triage before agent analysis
> 
> The label-based trigger gives you flexibility: auto-label for critical apps, manual label for others.

---

## Complete Flow Example

Let's walk through a real failure scenario:

### 1. Deployment Fails

A developer pushes a change with an invalid resource limit:

```yaml
# broken-aks-store-all-in-one.yaml
resources:
  limits:
    cpu: 25m
    memory: 1024Mi  # Oops, wrong unit - should be Mi not M
  requests:
    cpu: 5m
    memory: 75Mi
```

ArgoCD tries to sync, the pod enters `CrashLoopBackOff`, ArgoCD marks the app as `Degraded`.

### 2. Issue Created Automatically

The webhook fires, and an issue appears:

```markdown
## ArgoCD Deployment Failure

**Application:** `aks-store`
**Cluster:** `prod-west-aks`
**Namespace:** `pets`

### Application Status

| Field | Value |
|-------|-------|
| Health Status | `Degraded` |
| Sync Status | `OutOfSync` |

### Degraded Resources

#### Deployment: `store-front`

- **Health Status:** Degraded
- **Message:** Deployment has minimum availability

**Troubleshoot:**
kubectl describe deployment store-front -n pets
kubectl logs deployment/store-front -n pets
```

### 3. Cluster Doctor Triggered

Someone adds the `cluster-doctor` label (or it's auto-added). The agent:

1. **Reads the issue** via GitHub MCP
2. **Runs diagnostics** (if cluster access is configured)
3. **Posts a comment:**

```markdown
## Cluster Doctor Analysis

### Root Cause Identified

The deployment `store-front` is failing due to resource constraint issues:

1. **Memory limit mismatch:** The container requests 75Mi but is being OOM-killed 
   shortly after startup, suggesting the workload needs more than 1024Mi under load.

2. **Recommended fix:** Increase memory limit or investigate memory leak in application.

### Proposed Remediation

I've created PR #47 with the following changes:
- Increased memory limit from 1024Mi to 2048Mi
- Added resource quotas as a safety net

Please review and merge if acceptable.
```

### 4. PR Created

The agent creates a PR with:
- Branch: `fix/cluster-doctor/issue-42-20260210`
- Changes: Resource limit updates
- Test plan: How to validate in staging
- Rollback steps: How to revert if needed

---

## Workshop Activity: Build the Event-Driven Pipeline

**Time:** 45-60 minutes

### Part 1: Understand the Agent (15 min)

1. Read through [.github/agents/cluster-doctor.agent.md](../.github/agents/cluster-doctor.agent.md)
2. Identify the safety constraints built into the agent
3. **Discussion:** What other constraints would you add for your environment?

### Part 2: Simulate a Failure (15 min)

1. Review [argocd/apps/broken-aks-store-all-in-one.yaml](./argocd/apps/broken-aks-store-all-in-one.yaml)
2. Identify what's wrong with the manifest
3. Manually create a GitHub Issue that mimics what the ArgoCD workflow would create

### Part 3: Invoke the Agent (15 min)

1. Add the `cluster-doctor` label to your test issue
2. Watch the workflow run (Actions tab)
3. Review the agent's response in the issue comments

### Checkpoint Questions

- What information does the agent need to make accurate diagnoses?
- How would you extend the MCP configuration to give the agent cluster access?
- What failures should NOT trigger automatic agent analysis?

---

## Key Takeaways

- **Event-driven agents** respond to incidents faster than humans can context-switch
- **Structured issues** with full context enable better agent analysis
- **Safety constraints** in agent definitions prevent dangerous autonomous actions
- **GitOps PRs** create audit trails and require human approval for changes
- **Label-based triggers** give you control over when agents engage
- **The meta-benefit:** Building this pipeline forces you to define "what good looks like" for incident response

---

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| **Agent accesses wrong cluster** | Implement cluster identity verification (see agent safety section) |
| **Too many issues from transient failures** | Add debounce logic or require sustained degradation before alerting |
| **PRU cost surprises** | Set up usage monitoring; use label-triggers instead of auto-trigger |
| **Agent PRs that aren't reviewed** | Require approvals; set up PR review reminders |
| **Over-trusting agent diagnosis** | Always verify findings; treat agent output as suggestions, not commands |

---

## Reference Resources

**Workflows in This Repo:**
- [ArgoCD Deployment Failure Handler](../.github/workflows/argocd-deployment-failure.yml) — Creates issues from ArgoCD webhooks
- [Trigger Cluster Doctor](../.github/workflows/copilot.trigger-cluster-doctor.yml) — Invokes agent on labeled issues

**Agent Definition:**
- [Cluster Doctor Agent](../.github/agents/cluster-doctor.agent.md) — Full agent specification

**Configuration:**
- [MCP Config](../.copilot/mcp-config.json) — MCP server configuration for GitHub and cluster access
- [ArgoCD Setup Guide](./SETUP.md) — Complete ArgoCD notification configuration

**External Documentation:**
- [ArgoCD Notifications](https://argocd-notifications.readthedocs.io/)
- [GitHub Repository Dispatch](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#repository_dispatch)
- [GitHub Copilot CLI](https://docs.github.com/en/copilot/github-copilot-in-the-cli)

