Use the GitHub MCP Server to read GitHub Issue #${ISSUE_NUMBER} in the repository ${REPOSITORY}.

Extract the AKS cluster name and Azure resource group from the issue body.

Output ONLY two lines in this exact format (no other text, no markdown, no explanation):
RESOURCE_GROUP=<resource-group-name>
CLUSTER_NAME=<cluster-name>

If you cannot find both values in the issue body, output:
ERROR=Could not extract cluster info from issue body
