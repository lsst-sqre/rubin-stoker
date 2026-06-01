# Stoker profile for SQuaRE/Rubin Observatory

Rubin Observatory workflow settings for the [Stoker agentic engineering harness](https://github.com/jsickcodes/stoker).
*This workflow is experimental.* Contact @jonathansick for details.

This repository is a **stoker profile**: a directory of policy
(`settings.toml`, prompts, skills, issue templates, an onboarding interview,
and the egress-firewall allowlist) that `stoker install` vendors into a
consuming repository. The profile content lives under [`profile/`](profile/);
the profile name is `rubin`.

Stoker no longer ships a static sandbox `devcontainer.json`. Each consuming
repo keeps its own clean, human-usable `.devcontainer/devcontainer.json`, and
stoker **derives** its AFK sandbox into `.devcontainer/stoker/devcontainer.json`
from it (see [jsickcodes/stoker#207](https://github.com/jsickcodes/stoker/pull/207)
and `AGENTS.md`). This profile's job is to teach `stoker onboard devcontainer`
the Rubin defaults and to ship the firewall allowlist — not to own a
devcontainer.

## Installing the profile

In the repository you want to drive with stoker:

```sh
stoker install --profile github.com/lsst-sqre/rubin-stoker//profile@<ref>
```

Use a commit SHA or tag for `<ref>` so the install is reproducible. After
install, run the onboarding interview to teach stoker how *this* repo builds,
tests, and lints:

```sh
stoker onboard project-mechanics
```

This writes `.claude/skills/project-mechanics/SKILL.md` — the source of truth
the validation phases (`stoker-work`, `stoker-fixup`, `stoker-rebase`) read at
runtime. For a repo that runs testcontainers (e.g. docverse), the
`complete_test` command captured here is where the testcontainers env vars
live, for example:

```
TC_HOST=localhost TESTCONTAINERS_RYUK_DISABLED=true uv run --only-group=nox nox -s test
```

### Secrets

The Rubin profile declares these in `profile/settings.toml`:

| Secret | Required | Notes |
|--------|----------|-------|
| `gh_token` | **yes** | Pushes branches, posts reviews, files issues from the sandbox. |
| `signing_key_private` | **yes** | SSH private key — SQuaRE signs every commit. |
| `signing_key_public` | **yes** | Matching public key (allowed_signers). |
| `anthropic_key` | no | Only when running against the API rather than Claude Code subscription auth. |

The signing keys are **required** (unlike the upstream default profile, where
they are optional): the sandbox cannot produce a valid signed commit without
both halves. There is intentionally **no Jira token** — the sandbox AFK loop
never talks to Jira (see below).

### Atlassian (Jira) MCP — interactive only

The Jira-aware skills (`stoker-prd`, `stoker-prd-to-issues`,
`stoker-prd-followup`) read and comment on Jira through the
[Atlassian MCP server](https://rubinobs.atlassian.net/jira/), which you
configure in your interactive Claude Code environment. These skills run **on
the host**, never in the sandbox.

If the MCP server is not configured, the skills **degrade gracefully**: they
ask you to paste the ticket contents and print the Jira comment text for you
to paste back. The sandbox AFK loop is **GitHub-only** — it reads the Jira
key/URL from the GitHub issue metadata and has no Jira credentials, MCP, or
firewall egress to Jira.

## How the profile is organized

Everything not shown here is inherited from the upstream `default` profile
via stoker's per-file fallback ([jsickcodes/stoker#192](https://github.com/jsickcodes/stoker/pull/192)):

```
profile/
├── settings.toml                 # name="rubin", phase models, required secrets
├── skills/
│   ├── stoker-prd/               # Jira seed + comment
│   ├── stoker-prd-to-issues/     # Rubin branch naming + Jira metadata + comment
│   ├── stoker-prd-followup/      # Jira metadata + comment
│   └── stoker-create-pr/         # DM-XXXXX title + Jira reference
├── issue_templates/              # default + optional Jira Key/URL
│   ├── prd.yml
│   └── prd-task.yml
├── onboard/
│   └── devcontainer.md           # Rubin onboarding: Python+uv, DinD rule, signing
└── devcontainer/
    └── firewall-allowlist.txt    # + Docker Hub CDN / RFC1918 CIDRs
```

That is the complete set of nine Rubin-owned files. There is no profile
`devcontainer.json` or `Dockerfile`: the sandbox is derived from each repo's
own human devcontainer, and the no-source fallback Dockerfile (Python + uv) +
`codex-config.toml` come from the builtin `default` profile.

## Maintaining the profile

`stoker install` resolves each profile-relative path against this profile
first and falls back to the builtin `default` profile per file, so the only
files that need to live here are the ones Rubin actually customizes (the nine
listed above). The phase prompts, the un-customized skills
(`stoker-{work,implement,review,fixup,rebase}`), `onboard/project-mechanics.md`,
the no-source fallback `devcontainer/Dockerfile` (Python + uv), and
`devcontainer/codex-config.toml` are all supplied by the builtin default at
install time.

The four customized skills and `onboard/devcontainer.md` are **ported from the
upstream default bodies** with Rubin specifics layered on. Bump
[`UPSTREAM_STOKER_REF`](UPSTREAM_STOKER_REF) when you want to re-port against
a newer stoker; otherwise leave it alone — there is no longer any verbatim
sync to keep current. The pinned ref **must** be a stoker that inherits
`containerUser` / `privileged` in the sandbox derive (see `AGENTS.md`), or
Docker-in-Docker silently breaks in the sandbox.

```sh
# Pull the upstream base skills + onboard prompt into .upstream-cache/ for diffing:
make sync-upstream
diff -ru .upstream-cache/skills/stoker-prd profile/skills/stoker-prd
diff -u .upstream-cache/onboard/devcontainer.md profile/onboard/devcontainer.md

# Bump to a newer upstream ref before re-porting:
make sync-upstream STOKER_REF=<tag|branch|sha>
```

`make sync-upstream` never writes anything under `profile/` — the re-port is
fully manual. `make lint` runs the prek hygiene hooks (also enforced in CI).

## Known limitation: Docker-in-Docker vs the egress firewall

When a consuming repo's human devcontainer enables Docker-in-Docker (the
`docker-in-docker` Feature + `containerUser: root` + `privileged: true`),
stoker's derive carries that into the AFK sandbox so testcontainers can run
inside the loop. dockerd runs in the sandbox's root netns, so its *own* pull
egress is governed by the package `init-firewall.sh`, which installs an
allowlist on the filter `OUTPUT` chains only (verified: it never touches
`nat`/`FORWARD`, so it does not break dockerd's container forwarding). It
flushes/reinstalls those chains on every run and every 15 minutes via cron,
reading the relocated `.devcontainer/stoker/firewall-allowlist.txt`.

A Docker Hub `docker pull` is a **three-hop, two-cloud** path, and the
allowlist must cover all of it:

| Hop | Host | Backend | Allowlist coverage |
|-----|------|---------|--------------------|
| auth | `auth.docker.io` | Cloudflare | Cloudflare CIDRs |
| manifest | `registry-1.docker.io` | AWS compute | `getent` snapshot of the rotating IPs (refreshed by cron) |
| blobs | `production.cloudflare.docker.com` **or** `production.cloudfront.docker.com` | Cloudflare **or** AWS CloudFront | Cloudflare CIDRs **+ AWS CloudFront GLOBAL CIDRs** |

This profile's allowlist therefore ships the RFC1918 ranges (container/
testcontainer traffic after port DNAT), the Cloudflare edge CIDRs, **and** the
AWS CloudFront GLOBAL edge CIDRs (94 v4 + 30 v6). The CloudFront block is the
one added after live validation: Docker had silently moved `postgres:17`'s
blobs from Cloudflare to CloudFront (`18.67.17.89`), and a CloudFront-less
allowlist dropped the blob fetch with `connect: network is unreachable`. With
the CloudFront ranges in place, `docker pull postgres:17` and the testcontainers
suite come up in the sandbox.

**Residual fragility (tracked in
[jsickcodes/stoker#217](https://github.com/jsickcodes/stoker/issues/217)).**
The CloudFront list is a static snapshot of a moving target — Docker can
re-route blobs again, AWS adds CloudFront prefixes over time, and the manifest
hop rides a `getent` snapshot of general AWS-compute IPs. The robust long-term
fix is to sidestep Docker Hub's CDN entirely by mirroring testcontainer images
into the org's GHCR (`ghcr.io`/`pkg-containers.githubusercontent.com` are fully
covered by GitHub `/meta` → zero firewall change) or pulling them from another
stable, coverable registry.

If image pulls or testcontainer connections fail, find the blocked destination
with `sudo dmesg | grep STOKER-EGRESS-DROP` — the sandbox is a Debian container
with **no systemd, so `journalctl` is not installed** — then refresh the
relevant CIDR block (AWS CloudFront ranges come from
`https://ip-ranges.amazonaws.com/ip-ranges.json`, `service==CLOUDFRONT &&
region==GLOBAL`).
