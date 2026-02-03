# Act-3: Kubernetes Operations Don’t Scale Linearly

Problem:
Kubernetes becomes the operational choke point and your team in having a hard time dealing with misconfigurations, failed deployments and runtime issues.
Your team, platform engineering, is busy firefight instead of improving the platform. The deep Kubernetes expertise on your team doesn't scale across teams.

Answer:
Let agents give your team a hand, turning a siloed operational knowledge into a shared capability.

## Crawl

A Senior member of the team (Steve) has created a reusable prompts that can run arbitrarily when someone needs to troubleshoot a container workload on an AKS cluster. Steve made this available in the repo and this can be used in GitHub Copilot in VSCode via "Slash Commands" if you follow the folder/naming convension set out by GitHub/VScode (i.e. `<repo-root>/.github/prompts/<prompt-name>.prompt.md`).

Execute this prompt locally:

![write-prompt](images/write-prompt.png)

## Walk/Run

Create a GitHub Action Workflow that will be called upon for each push to the repo.  For this example it will be just for the main branch, but you can set up the triggers/rules for when the workflow gets run.  See the docs about [Events That Trigger Workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows).

> [!NOTE]
> We will use the GitHub Copilot CLI to automate the execution of our custom prompt in a scripted CI Runner - GitHub Actions.

We have an example of this in [Act-2 .github/workflows](../.github/workflows/copilot.generate-docs.yml).

### What does this do?

- The GitHub Action Workflow triggers on each push to the main branch - this ensures that documentation is created, if and when needed regardless if you remembered or not.  This ensures that all team members have docs created for them, even if they did not run the `/write-docs` prompt manually before committing their changes.  It also can be run manually in GitHub Actions since it also has the `workflow_dispatch` trigger enabled...this is optional of course but we have it here as an example anyways.
- It installs the GitHub Copilot CLI
- It ensures that we provide it credentials to call GitHub Copilot
> [!NOTE]
> Currently calling GitHub Copilot is a User only ability - meaning that GitHub Copilot is licensed to and therefore only callable by a human user account. In this example we have stored a Fine-Grained GitHub Personal Access Token (PAT -> a user bound API Key) that has been scoped with the `Copilot-Requests: Read-only` Permission.  As such this will consume GitHub Copilot PRUs (Premium Request Units) from the tied user account.  Today this is the only billing model to consume GitHub Copilot.
- Store the required prompt file contents as an environment variable
- Pass in the prompt and call GitHub Copilot CLI to generate docs