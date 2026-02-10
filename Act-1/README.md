# Act 1: The Platform Is Growing Faster Than the Team

> **Workshop Goal:** Learn how to leverage AI agents to capture, scale, and operationalize platform engineering knowledge before it becomes a bottleneck.

---

## The Scene: A Familiar Story

Your platform team is successful—maybe too successful. Adoption is up, teams are onboarding, and requests are flooding in. But here's the dirty enterprise secret no one talks about:

**You either don't have enterprise guidelines** (incomplete, outdated, tribal, or completely absent) **or you have too many rules** and no single human can absorb, filter, and apply them consistently and coordinating within a team is complicated.

Sound familiar?

---

## The Problem: Knowledge Doesn't Scale Like Infrastructure

As platforms grow, these concerns multiply and compound:

| Challenge | The Reality |
|-----------|-------------|
| **Tribal Knowledge** | Critical knowledge lives in people's heads, not systems. When they're on vacation, in meetings, or leave the company—it goes with them. |
| **Documentation Drift** | Templates and docs go stale within weeks. Change management can't keep pace with actual changes. |
| **Copy/Paste Engineering** | Developers copy examples without understanding guardrails. Deadlines don't allow for deep dives. |
| **Support Bottleneck** | The platform team answers the same questions repeatedly. Every "quick question" in Slack is a context switch. |
| **Governance Gaps** | Security and compliance requirements are inconsistently applied. What passes review depends on who reviews it. |
| **Onboarding Drag** | New team members take weeks or months to become productive. The ramp-up cost compounds with every hire. |
| **Hidden Standards** | Best practices exist somewhere—wikis, old PRs, someone's local notes—but they're not discoverable or enforced. |

**The core issue:** Your platform team's knowledge is the bottleneck, not your infrastructure.

---

## The Opportunity: Agents as Knowledge Multipliers

What if you could:
- Encode your senior engineers' expertise into something that scales infinitely?
- Answer the "same questions" automatically, 24/7, with consistent quality?
- Apply guardrails and best practices at the point of creation, not in code review?
- Onboard new developers in hours instead of weeks?

**This is where AI agents come in.**

Agents aren't replacing your platform team—they're amplifying it. Think of them as "expertise capture" that turns tribal knowledge into operational capability.

---

## Exercise: Build Your First Platform Agent

### Getting Started

If you've never written a custom agent before, use our starter prompt template: [starter-prompt.md](./starter-prompt.md)

### The Agent Crafting Framework

When building an effective platform agent, follow this progression:

#### 1. Define the Persona
Give the agent a clear role and identity.

```
"You are a Principal Infrastructure Architect with 15 years of experience 
in enterprise cloud platforms..."
```

#### 2. Establish Purpose and Goals
A persona alone isn't enough—define the agent's "meaning in life" and what success looks like.

```
"Your goal is to help development teams design and deploy infrastructure 
that meets our enterprise standards for security, cost efficiency, and 
operational excellence..."
```

#### 3. Codify Workflow Rules
Document the things your team knows but hasn't written down. These are your implicit standards.

```
"Before approving any infrastructure design:
- Verify network isolation requirements are met
- Confirm cost estimates are within team budgets
- Check for existing shared services that could be reused..."
```

#### 4. Provide Concrete Examples
Words aren't enough—show specific examples of how your team handles real scenarios.

```
"Example: When a team requests a new Kubernetes cluster, you should:
1. First ask about their workload characteristics (stateless/stateful, traffic patterns)
2. Recommend our standard AKS configuration from [template-repo]
3. Walk them through the required networking setup for their environment tier..."
```

#### 5. Embrace Clarification
Instruct the agent to ask questions when requirements are ambiguous rather than making assumptions.

```
"If the request is unclear or missing critical information, ask clarifying 
questions before proceeding. It's better to slow down than to provide 
incorrect guidance..."
```

#### 6. Ground in Documentation
Link to authoritative sources—your organization's standards, recent documentation, or external references the agent should consult.

```
"Refer to these resources for authoritative guidance:
- Internal: [link to architecture decision records]
- Internal: [link to security baseline requirements]
- External: [Azure Well-Architected Framework]..."
```

---

## Workshop Activity

**Time:** 30 minutes

1. **Identify** one recurring question or task your platform team handles repeatedly
2. **Draft** a custom agent prompt using the framework above
3. **Test** your agent against 3 real scenarios from the past month
4. **Iterate** based on where the agent's guidance diverges from what you'd actually recommend

**Discussion:** What tribal knowledge surfaced while writing your prompt that wasn't documented anywhere?

---

## Key Takeaways

- Platform engineering bottlenecks are often **knowledge problems**, not infrastructure problems
- AI agents can capture and scale expertise that previously only lived in people's heads
- The act of crafting an agent **forces documentation** of implicit standards and workflows
- Start small: one agent solving one repeated problem is more valuable than a perfect comprehensive solution

---

## Reference Resources

**Building IaC and CI/CD Agents:**
- [IaC Module Catalog Agent](https://github.com/ricardocovo/iac-module-catalog) - Using agents to help write Infrastructure as Code and CI/CD pipelines

**Reverse Engineering Existing Infrastructure:**
- [Infrastructure Reverse Engineer Agent](https://github.com/ricardocovo/ghcp-infra-reverse-engineer) - Using agents to understand and document existing infrastructure

---

## Next Up

In **[Act 2](../Act-2/README.md)**, we'll explore how to integrate these agents into your developer workflows and inner loop experiences.