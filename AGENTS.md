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

### The two-devcontainer model

Since [jsickcodes/stoker#207](https://github.com/jsickcodes/stoker/pull/207),
stoker no longer ships a single static sandbox `devcontainer.json` that
clobbers a repo's own dev container. Two devcontainers coexist:

1. The **project** ships a clean, human-usable
   `.devcontainer/devcontainer.json` (+ `.devcontainer/Dockerfile`) — project
   tooling only (base image, Features, a project `postCreateCommand`). Humans
   use it locally and in Codespaces. Rubin teaches `stoker onboard
   devcontainer` how to author it via `profile/onboard/devcontainer.md`.
2. Stoker **derives** `.devcontainer/stoker/devcontainer.json` from it on
   `stoker install` / `upgrade` (pure transform in
   `src/stoker/install/devcontainer.py`). The derive inherits the project's
   `build`/`image`, `features`, `hostRequirements`, `securityOpt`,
   `containerUser`, `privileged`, non-reserved `containerEnv`, `runArgs`
   (unioned with stoker's `NET_ADMIN`/`NET_RAW` caps), and `postCreateCommand`
   (after stoker's firewall prelude); **forces** name/workspace/`remoteUser`/
   mounts/clone/firewall; and **strips** editor/host-only keys.

Stoker's operational stack (firewall, sudo, cron, 1Password, NOPASSWD
sudoers) is now a package-shipped devcontainer Feature (`stoker-sandbox`,
force-injected by the derive) — no longer baked into any profile Dockerfile.
The practical consequence for Rubin: a single profile serves Python *and* JS
projects, and this profile ships **no** `devcontainer.json` / `Dockerfile` —
only the firewall allowlist and the onboarding prompt that bakes in Rubin's
defaults.

**stoker dependency (DinD):** the derive only carries `containerUser` /
`privileged` through to the sandbox on a stoker that includes the
[`containerUser`/`privileged` passthrough](https://github.com/jsickcodes/stoker/pull/207).
The pinned `UPSTREAM_STOKER_REF` **must** include it, or a Rubin repo's
docker-in-docker (testcontainers) silently breaks in the AFK sandbox with
`Shell server terminated (code: 126)` / `no users found` — see the onboard
prompt entry below.

### Rubin-owned files

Everything in `profile/` is Rubin-owned by definition. There are nine of them
(eight policy files plus the onboarding prompt):

- `profile/settings.toml` — name, phase models, required secrets.
- `profile/issue_templates/prd.yml`, `prd-task.yml` — default fields + optional
  Jira Key/URL.
- `profile/skills/stoker-prd/SKILL.md` — Jira seed + comment.
- `profile/skills/stoker-prd-to-issues/SKILL.md` — Rubin branch naming + Jira
  metadata + comment.
- `profile/skills/stoker-prd-followup/SKILL.md` — Jira metadata + comment.
- `profile/skills/stoker-create-pr/SKILL.md` — `DM-XXXXX:` title + `Jira:`
  reference.
- `profile/devcontainer/firewall-allowlist.txt` — + Docker Hub CDN / RFC1918
  CIDRs (for DinD/testcontainers egress; no builtin equivalent). The package
  `init-firewall.sh` reads it from `.devcontainer/stoker/firewall-allowlist.txt`
  after the sandbox component relocates it there.
- `profile/onboard/devcontainer.md` — Rubin-flavored `stoker onboard
  devcontainer` prompt: Python + uv defaults (`postCreateCommand: uv sync`),
  and the **DinD rule** — a repo running testcontainers must add the
  `docker-in-docker` Feature *and* set top-level `containerUser: "root"` *and*
  `privileged: true` in the **human** `.devcontainer/devcontainer.json`. These
  are *project* concerns (the project needs DinD), so they belong in the human
  config; stoker's derive carries them into the sandbox. The DinD feature's
  `docker-init.sh` runs as PID 1 and only starts dockerd cleanly as root —
  without `containerUser: "root"` the sandbox fails to come up
  (`Shell server terminated (code: 126)` / `no users found`). SSH commit
  signing is configured per-session by stoker's package code from the injected
  `signing_key_*` secrets, so the prompt tells onboarding **not** to bake
  signing into the human devcontainer.

Everything else — the phase prompts, the un-customized
`stoker-{work,implement,review,fixup,rebase}` skills,
`onboard/project-mechanics.md`, the no-source fallback `devcontainer/Dockerfile`
(Python + uv), and `devcontainer/codex-config.toml` — is supplied by the builtin
`default` profile via per-file fallback at install time.

The four Rubin-owned `stoker-{prd,prd-to-issues,prd-followup,create-pr}`
skills are **ported from the upstream default skill bodies** (which carry the
robust multi-task PR logic, sentinel formats, and sub-issue/blocker plumbing)
with Rubin specifics layered on — not copied from the older hand-rolled
docverse skills. `profile/onboard/devcontainer.md` is likewise ported from the
upstream onboard prompt with the Rubin defaults layered on. When bumping the
pinned upstream ref, re-port any upstream changes to those files by hand using
the diff workflow below.

### Syncing from upstream

The pinned `jsickcodes/stoker` ref lives in `UPSTREAM_STOKER_REF`. There are
no verbatim files to overwrite anymore, so `make sync-upstream` is a
**diff-only fetch**: it shallow-clones stoker at the pinned ref (or
`make sync-upstream STOKER_REF=<ref>` to bump the pin) and copies the four
upstream base skills into `.upstream-cache/skills/` and the upstream onboard
prompt into `.upstream-cache/onboard/devcontainer.md` (both gitignored) so you
can `diff -ru` / `diff -u` them against `profile/skills/*` and
`profile/onboard/devcontainer.md` during a re-port. Nothing under `profile/` is
ever written by the script.

### Jira boundary

All Jira reads/comments happen **interactively, on the host**, via the
Atlassian MCP server, and the Jira-aware skills degrade gracefully when it is
absent. The sandbox AFK loop is **GitHub-only**: it carries no Jira token, MCP,
or firewall egress to Jira, and reads the Jira key/URL only from GitHub issue
metadata that `stoker-prd-to-issues` propagates onto each task.
