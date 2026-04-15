#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────
# Run the Copilot CLI agent inside a network-isolated container.
#
# All HTTP/HTTPS traffic is routed through a Squid proxy that
# enforces a domain allowlist. The allowlist is passed as a
# newline-delimited string via --allowed-domains.
#
# Usage:
#   .github/scripts/run-sandboxed-agent.sh \
#     --kubeconfig "$HOME/.kube/config" \
#     --allowed-domains "$ALLOWED_DOMAINS" \
#     --prompt-file /tmp/prompt.md \
#     --output-file agent-output.json \
#     --mcp-config .copilot/mcp-config.json \
#     --copilot-token "$COPILOT_CLI_TOKEN" \
#     --github-mcp-token "$GITHUB_TOKEN"
# ──────────────────────────────────────────────────────────

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --allowed-domains) ALLOWED_DOMAINS="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --output-file) OUTPUT_FILE="$2"; shift 2 ;;
    --mcp-config) MCP_CONFIG="$2"; shift 2 ;;
    --copilot-token) COPILOT_TOKEN="$2"; shift 2 ;;
    --github-mcp-token) GITHUB_MCP_TOKEN="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

NETWORK_NAME="agent-net-$$"
PROXY_CONTAINER="squid-proxy-$$"
AGENT_CONTAINER="agent-$$"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cleanup() {
  echo "Cleaning up containers and network..."
  docker rm -f "$PROXY_CONTAINER" 2>/dev/null || true
  docker rm -f "$AGENT_CONTAINER" 2>/dev/null || true
  docker network rm "$NETWORK_NAME" 2>/dev/null || true
}
trap cleanup EXIT

# ── Build agent image (cached after first run) ──
echo "Building agent container image..."
docker build -t cluster-doctor-agent:local \
  -f "$REPO_ROOT/.github/containers/agent/Dockerfile" \
  "$REPO_ROOT/.github/containers/agent/" \
  --quiet

# ── Create isolated Docker network ──
echo "Creating isolated network: $NETWORK_NAME"
docker network create --internal "$NETWORK_NAME"

# ── Write domain allowlist to temp file ──
DOMAINS_FILE=$(mktemp)
echo "$ALLOWED_DOMAINS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' > "$DOMAINS_FILE"

echo "Domain allowlist:"
cat "$DOMAINS_FILE" | sed 's/^/  /'
echo ""

# ── Start Squid proxy ──
echo "Starting Squid proxy..."
docker run -d \
  --name "$PROXY_CONTAINER" \
  --network "$NETWORK_NAME" \
  -v "$REPO_ROOT/.github/containers/proxy/squid.conf:/etc/squid/squid.conf:ro" \
  -v "$DOMAINS_FILE:/etc/squid/allowed-domains.txt:ro" \
  ubuntu/squid:latest

# Proxy needs bridge access to reach the internet on behalf of the agent
docker network connect bridge "$PROXY_CONTAINER"

sleep 3
echo "Proxy ready"

# ── Run agent in isolated container ──
echo "Starting agent container (network-isolated, proxy-gated)..."
docker run --rm \
  --name "$AGENT_CONTAINER" \
  --network "$NETWORK_NAME" \
  -e "HTTP_PROXY=http://$PROXY_CONTAINER:3128" \
  -e "HTTPS_PROXY=http://$PROXY_CONTAINER:3128" \
  -e "NO_PROXY=localhost,127.0.0.1" \
  -e "GITHUB_TOKEN=$COPILOT_TOKEN" \
  -e "GITHUB_MCP_TOKEN=$GITHUB_MCP_TOKEN" \
  -e "KUBECONFIG=/home/agent/.kube/config" \
  -v "$KUBECONFIG_PATH:/home/agent/.kube/config:ro" \
  -v "$REPO_ROOT:/workspace:ro" \
  -v "$(dirname "$OUTPUT_FILE"):/output:rw" \
  -v "$PROMPT_FILE:/tmp/prompt.md:ro" \
  -w /workspace \
  cluster-doctor-agent:local \
  -c '
    kubectl port-forward -n aks-mcp svc/aks-mcp 8000:8000 &
    sleep 3

    copilot -p "$(cat /tmp/prompt.md)" \
      --agent "cluster-doctor" \
      --additional-mcp-config @"'"$MCP_CONFIG"'" \
      --allow-all-tools

    if [ -f agent-output.json ]; then
      cp agent-output.json /output/'"$(basename "$OUTPUT_FILE")"'
    fi
  '

echo "Agent container exited"

# Verify output
if [ -f "$OUTPUT_FILE" ]; then
  echo "Agent output produced: $OUTPUT_FILE"
  python3 -c "import json; json.load(open('$OUTPUT_FILE'))" || {
    echo "ERROR: agent-output.json is not valid JSON"
    exit 1
  }
else
  echo "ERROR: Agent did not produce output"
  exit 1
fi

# Full audit trail
echo ""
echo "=== Proxy access log (all agent network activity) ==="
docker logs "$PROXY_CONTAINER" 2>&1 | grep -v "cache.log" || true
