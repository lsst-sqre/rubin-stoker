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

The installable profile lives under `profile/`. `stoker install` resolves
profile files **per-relative-path with fallback to the builtin `default`
profile**: the active profile's copy wins, and the builtin copy fills any gap
(see `src/stoker/profile/fallback.py` upstream, introduced in
[jsickcodes/stoker#192](https://github.com/jsickcodes/stoker/pull/192) and
documented in `docs/design.md`). Single-file sources (phase prompts, onboard
prompts, individual devcontainer files) and directory sources (`skills/`,
`prompts/`, `issue_templates/`) all layer the same way; `settings.toml` is the
one exception — it is layered separately by the config loader. The practical
consequence: this profile only needs to ship the files it actually
customizes, and the builtin default supplies everything else at install time.

### Rubin-owned files

Everything in `profile/` is Rubin-owned by definition. There are ten of them:

- `profile/settings.toml` — name, phase models, required secrets.
- `profile/issue_templates/prd.yml`, `prd-task.yml` — default fields + optional
  Jira Key/URL.
- `profile/skills/stoker-prd/SKILL.md` — Jira seed + comment.
- `profile/skills/stoker-prd-to-issues/SKILL.md` — Rubin branch naming + Jira
  metadata + comment.
- `profile/skills/stoker-prd-followup/SKILL.md` — Jira metadata + comment.
- `profile/skills/stoker-create-pr/SKILL.md` — `DM-XXXXX:` title + `Jira:`
  reference.
- `profile/devcontainer/Dockerfile` — Python + uv + SSH signing + tooling.
- `profile/devcontainer/devcontainer.json` — + Docker-in-Docker.
- `profile/devcontainer/firewall-allowlist.txt` — + Docker Hub CDN / RFC1918
  CIDRs.

The four Rubin-owned `stoker-{prd,prd-to-issues,prd-followup,create-pr}`
skills are **ported from the upstream default skill bodies** (which carry the
robust multi-task PR logic, sentinel formats, and sub-issue/blocker plumbing)
with Rubin specifics layered on — not copied from the older hand-rolled
docverse skills. When bumping the pinned upstream ref, re-port any upstream
changes to those four skills by hand using the diff workflow below.

### Syncing from upstream

The pinned `jsickcodes/stoker` ref lives in `UPSTREAM_STOKER_REF`. There are
no verbatim files to overwrite anymore, so `make sync-upstream` is a
**diff-only fetch**: it shallow-clones stoker at the pinned ref (or
`make sync-upstream STOKER_REF=<ref>` to bump the pin) and copies the four
upstream base skills into a gitignored `.upstream-cache/skills/` so you can
`diff -ru` them against the corresponding `profile/skills/*` directory during
a re-port. Nothing under `profile/` is ever written by the script.

### Jira boundary

All Jira reads/comments happen **interactively, on the host**, via the
Atlassian MCP server, and the Jira-aware skills degrade gracefully when it is
absent. The sandbox AFK loop is **GitHub-only**: it carries no Jira token, MCP,
or firewall egress to Jira, and reads the Jira key/URL only from GitHub issue
metadata that `stoker-prd-to-issues` propagates onto each task.
