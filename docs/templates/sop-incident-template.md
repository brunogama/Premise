---
type: sop
description: <one-line summary>
date: YYYY-MM-DD
status: draft
severity: <sev1 | sev2 | sev3>
owner: <on-call role>
version: 0.1.0
---

# <Incident response title>

## Rule

> **When <trigger>, follow this procedure without deviation.**

## Rationale

<Why this runbook exists; link past incidents.>

## Scope

<Systems, environments, and roles covered.>

## Detection

- <signal, alert, or metric that triggers this SOP>
- <command or dashboard to confirm>

## Procedure

1. **Triage** Ñ <assess blast radius, declare severity>.
2. **Mitigate** Ñ <stop-the-bleeding actions first>.
3. **Resolve** Ñ <root-cause fix steps>.
4. **Verify** Ñ <health checks confirming recovery>.

## Rollback

1. <exact rollback command or step>

## Escalation

| Condition | Escalate to |
|-----------|-------------|
| <condition> | <role/contact> |

## Post-incident

- [ ] Timeline documented
- [ ] Follow-up issues filed
- [ ] SOP updated with lessons learned
