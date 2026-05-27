rubin-stoker is a profile plugin for the [Stoker](https://github.com/jsickcodes/stoker) agentic engineering harness.
This profile captures the workflow defaults for Rubin Observatory work, such as in the https://github.com/lsst-sqre GitHub organization.

## Rubin Observatory-specific workflow considerations

### Jira integration

Work starts with Jira tickets, and we use Jira tickets as a central communication touch point for high-level stakeholders.
We use the Atlassian instance hosted at https://rubinobs.atlassian.net/jira/.
Our Jira tickets typically have `DM-` prefixes (e.g., `DM-12345`).

When creating a PRD, we'll pass in a reference to the Jira ticket. The `/stoker-prd` skill should use the Jira ticket description as the seed for the PRD, in addition to any additional context that the user provides. Jira ticket descriptions as high-level, so a PRD needs to translate  tickets into technical and actionable designs.

When we create the PRD and create implementation tasks we want to post comments to the Jira ticket to keep stakeholders updated with out progress.

Our preference is to use the Atlassian MCP server for interacting with Jira. The user should configure this MCP server.

### Git branch naming

Work should always be done on a branch, never on the default branch (typically `main`).
When doing work associated with a Jira ticket, the branch name should have a `tickets/` prefix followed by the ticket (e.g., `tickets/DM-12345`).
If there's only one Git branch for a Jira ticket, you can just use that branch name.
But if there are multiple Git branches for a Jira ticket, then add a short description suffix that's dash separated (e.g., `tickets/DM-12345-feature-a` and `tickets/DM-12345-feature-b`).

### Working without a Jira ticket

Some PRDs are small, and can be created without a Jira ticket. In that case, the Git branch template is `u/<username>/<description>` where `<username>` is the user's GitHub username.
For example, `u/jonathansick/docs-fix`.

## Profile structure and maintenance

The installable profile lives under `profile/`. `stoker install` vendors it
into a consuming repo (skills → `.claude/skills/` and `.agents/skills/`,
prompts → `.stoker/prompts/`, issue templates → `.github/ISSUE_TEMPLATE/`,
devcontainer → `.devcontainer/`). Install is **replace-not-merge with no
inheritance**, and this stoker version ships no builtin package-prompt
fallback, so the profile must ship the **complete** set of skills and prompts —
including the ones it does not customize.

### Ownership table

The sync script (`scripts/sync-upstream.sh`) is kept in lockstep with this
table. Rubin-owned files are authored here and never overwritten by the sync;
verbatim files are pulled from the pinned upstream ref.

| Path | Owner |
|------|-------|
| `profile/settings.toml` | **Rubin** — name, phase models, required secrets |
| `profile/issue_templates/prd.yml`, `prd-task.yml` | **Rubin** — default + optional Jira Key/URL |
| `profile/skills/stoker-prd/` | **Rubin** — Jira seed + comment |
| `profile/skills/stoker-prd-to-issues/` | **Rubin** — Rubin branch naming + Jira metadata + comment |
| `profile/skills/stoker-prd-followup/` | **Rubin** — Jira metadata + comment |
| `profile/skills/stoker-create-pr/` | **Rubin** — `DM-XXXXX:` title + `Jira:` reference |
| `profile/devcontainer/Dockerfile` | **Rubin** — Python + uv + SSH signing + tooling |
| `profile/devcontainer/devcontainer.json` | **Rubin** — + Docker-in-Docker |
| `profile/devcontainer/firewall-allowlist.txt` | **Rubin** — + Docker Hub CDN / RFC1918 CIDRs |
| `profile/skills/stoker-work/`, `stoker-implement/`, `stoker-review/`, `stoker-fixup/`, `stoker-rebase/` | verbatim (synced) |
| `profile/prompts/*.md` | verbatim (synced) |
| `profile/onboard/project-mechanics.md` | verbatim (synced) |
| `profile/devcontainer/codex-config.toml` | verbatim (synced) |

The four Rubin-owned skills are **ported from the upstream default skill
bodies** (which carry the robust multi-task PR logic, sentinel formats, and
sub-issue/blocker plumbing) with Rubin specifics layered on — not copied from
the older hand-rolled docverse skills. When bumping the pinned ref, re-port any
upstream changes to those four skills by hand and review the diff.

### Syncing from upstream

The pinned `jsickcodes/stoker` ref is recorded in `UPSTREAM_STOKER_REF`. Re-run
`make sync-upstream` to refresh the verbatim files against it, or
`make sync-upstream STOKER_REF=<ref>` to bump the pin. Always review the
resulting `git diff`.

### Jira boundary

All Jira reads/comments happen **interactively, on the host**, via the
Atlassian MCP server, and the Jira-aware skills degrade gracefully when it is
absent. The sandbox AFK loop is **GitHub-only**: it carries no Jira token, MCP,
or firewall egress to Jira, and reads the Jira key/URL only from GitHub issue
metadata that `stoker-prd-to-issues` propagates onto each task.
