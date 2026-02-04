---
name: Analyze Commit for Documentation Needs
description: Analyze a specific commit to determine if documentation updates are required and create a GitHub issue if necessary.
---

# Analyze Commit and Create Documentation Issue

Analyze commit `{COMMIT_SHA}` in repository `{REPOSITORY}` using the GitHub MCP server.

## Your Task

1. **Examine the commit** using MCP to access:
   - Commit diff and changed files
   - Current documentation structure
   - Project context

2. **Decide if documentation is needed** based on these criteria:

   ### ✅ Document These:
   - Public APIs/Interfaces (functions, classes, endpoints)
   - Complex logic requiring explanation
   - Architectural or workflow changes
   - Breaking changes
   - New dependencies or integrations
   - Security/performance changes
   - Database schemas or data models
   - Unit tests

   ### ❌ Skip These:
   - Minor refactoring or formatting
   - Internal helpers
   - Trivial typo fixes
   - Code moves without logic changes
   - Patch dependency updates
in the current repository
   - Add labels: `documentation`, `automated`
3. **If documentation is needed:**
   - Use the GitHub MCP server to create a GitHub issue with title: "📚 Documentation needed for commit test" 
   - Use assign_copilot_to_issue tool to assign @copilot to issue.
   - In the issue body, explain:
     - What changed and why it needs documentation
     - Which documentation files should be updated
     - Any breaking changes or migration notes needed
   - Confirm if all steps succeeded or not.

4. **If documentation is NOT needed:**
   - Simply explain why in a brief response (no issue needed)
