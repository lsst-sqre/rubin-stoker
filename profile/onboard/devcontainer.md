# Onboard a project-fitting devcontainer (Rubin Observatory)

You are running on the **host** (outside the stoker devcontainer), as
part of `stoker onboard devcontainer`. Your job is to interview the user
about how this project is developed, then author a normal,
general-purpose `.devcontainer/devcontainer.json` (plus a `.devcontainer/
Dockerfile`) tuned to the repo.

This is the repo's **own** dev container — the one a human uses locally or
in Codespaces. It is *not* stoker's sandbox. Stoker keeps its sandbox in a
separate, stoker-owned `.devcontainer/stoker/devcontainer.json` that it
**derives** from this file on `stoker install` / `stoker upgrade`: it
inherits your base image / build, Features, `hostRequirements`,
`securityOpt`, `containerUser`, `privileged`, and `postCreateCommand`, then
force-layers its own invariants (clone-into-a-volume workspace, egress
firewall, harness install) via the `stoker-sandbox` devcontainer Feature.

So author this file as a clean, project-only dev container. Do **not** add
any stoker concerns — no firewall step, no repo clone, no volume
`workspaceMount`, no `NET_ADMIN` / `NET_RAW` caps, no `STOKER_*` env, no
commit-signing config. The derive adds all of that (and the sandbox
configures commit signing per-session, see "SSH commit signing" below).
Keeping them out is also what lets `stoker doctor` confirm this human config
stays clean.

## Rubin defaults

Most Rubin Observatory / SQuaRE repos (the `lsst-sqre` GitHub org) share a
common shape. Use these as your starting assumptions and confirm them
against the repo rather than asking from scratch:

- **Python + uv.** The default base is the latest Python the repo supports
  (read `requires-python` in `pyproject.toml`; e.g. `>=3.13` → the
  `mcr.microsoft.com/devcontainers/python:1-3.13-bookworm` base) plus `uv`
  installed in the Dockerfile. The default `postCreateCommand` is
  `uv sync` (cite `pyproject.toml` / `uv.lock`). Many repos also have a
  Node-based component (a Cloudflare worker, a docs site) — add the
  `node` Feature pinned to the version the project requires (check
  `package.json` `engines` / `.nvmrc`; the docverse worker needs `>=22`).

- **Docker-in-Docker for testcontainers (CRITICAL).** Repos whose test
  suite uses **testcontainers** (Postgres, Redis, …) must run
  Docker-in-Docker in stoker's AFK sandbox. For that to work the *human*
  `.devcontainer/devcontainer.json` must declare **all three** of:

  1. the `ghcr.io/devcontainers/features/docker-in-docker:2` Feature, and
  2. top-level `"containerUser": "root"`, and
  3. top-level `"privileged": true`.

  These are **project** concerns, not stoker concerns: the *project* needs
  DinD, so they legitimately belong in the human config. The DinD Feature's
  `docker-init.sh` runs as **PID 1** and only starts `dockerd` cleanly when
  the container user is **root**; `--privileged` is what lets dockerd manage
  iptables/cgroups inside the container. Stoker's derive carries
  `containerUser`, `privileged`, the Feature, and `runArgs` (unioning
  `--privileged` with stoker's caps) straight into the derived sandbox — so
  the AFK loop's DinD comes up exactly as it does for a human.

  > **Failure mode if you omit `containerUser: root`:** the sandbox dies on
  > startup with `Shell server terminated (code: 126)` / `no users found`
  > because `docker-init.sh` can't start dockerd as a non-root PID 1. If you
  > see that, the human devcontainer is missing `containerUser: "root"`.
  > Don't relearn this the hard way.

  > **Stoker dependency:** the `containerUser` / `privileged` passthrough
  > requires a stoker that inherits both keys in the derive (see
  > `AGENTS.md`). The pinned `UPSTREAM_STOKER_REF` must include it, or Rubin
  > DinD silently breaks even with a correct human config.

  Keep `"remoteUser": "vscode"` so unprivileged lifecycle / agent commands
  still run as `vscode` — the container *starts* as root (for docker-init)
  but the agent does not run as root.

- **SSH commit signing — do NOT bake it in.** SQuaRE signs every commit with
  SSH, but the stoker sandbox configures this **per session** from the
  injected `signing_key_private` / `signing_key_public` secrets (the package
  `agent-entry.sh` sets `user.signingkey` /
  `gpg.ssh.allowedSignersFile` at the start of each run). So do **not** add
  `commit.gpgsign` / `gpg.format` / `user.signingkey` to the human
  devcontainer or its Dockerfile — it is redundant in the sandbox and noise
  for local human development.

## Phase 0: Read the repo to ground your questions

Before asking the user anything, briefly scan the repo so your questions
are pointed:

- `README.md` / `CONTRIBUTING.md` — setup steps usually name the runtime,
  package manager, and system dependencies.
- `pyproject.toml` / `package.json` / `Cargo.toml` / `go.mod` — language(s),
  version constraints (`requires-python`, `engines`), and the build/run
  entrypoint.
- Lockfiles (`uv.lock`, `pnpm-lock.yaml`, `package-lock.json`, …) — the
  package manager to standardize on.
- Test config and `noxfile.py` / CI workflows under `.github/workflows/` —
  whether the suite uses **testcontainers** (look for `testcontainers`,
  `TC_HOST`, `TESTCONTAINERS_RYUK_DISABLED`, a Postgres/Redis fixture),
  which is the signal you need the DinD trio above.

If something is obvious from the source, state it and confirm rather than
asking from scratch ("It looks like a Python 3.13 project using `uv` with
testcontainers-based Postgres tests — I'll base the image on the
`devcontainers/python:1-3.13` base, add the `docker-in-docker` Feature, and
set `containerUser: root` + `privileged: true` so DinD works in the sandbox.
OK?"). Cite a file path when you do.

## Phase 1: Interview

Cover, in order:

1. **Base image / language runtime.** Confirm the Python version from
   `requires-python`. Prefer a `mcr.microsoft.com/devcontainers/*` base.
2. **System packages.** Anything apt-level the build/tests need (e.g.
   `libpq-dev`, `graphviz`)?
3. **Devcontainer Features.** `node` (which version?), `docker-in-docker`
   (required if the suite uses testcontainers — and then also set
   `containerUser: root` + `privileged: true`, per Rubin defaults). Stoker's
   sandbox Feature is layered separately — don't add it here.
4. **postCreateCommand.** Default `uv sync`; add more if the project needs
   it. Keep it to project setup only — stoker runs it **after** its firewall
   prelude in the derived sandbox.
5. **Editor customizations (optional).** VS Code extensions / settings the
   team standardizes on (e.g. `ms-python.python`, `charliermarsh.ruff`).
   These live under `customizations`, for the human config only (stoker
   strips them from its sandbox).

## Phase 2: Draft

Author two files:

- `.devcontainer/Dockerfile` — a minimal base for the chosen Python runtime
  plus `uv` and any system packages. Keep it project-only — **no** firewall,
  sudo, cron, gh, 1Password, or commit-signing config (those are the
  `stoker-sandbox` Feature's / package's job). Keep it COPY-free so the
  human build and the cloned-volume sandbox build are identical.
- `.devcontainer/devcontainer.json` — `build` pointing at that Dockerfile
  (with `"context": ".."` if the Dockerfile needs the repo root), the agreed
  Features, the `postCreateCommand`, and — when the suite uses testcontainers
  — `containerUser: "root"` + `privileged: true` + `remoteUser: "vscode"`.
  Plain JSON-with-comments is fine.

A minimal Python + Node + DinD shape (testcontainers project):

```jsonc
{
  "name": "<project>",
  "build": { "dockerfile": "Dockerfile", "context": ".." },
  "features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "22" },
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  "containerUser": "root",
  "remoteUser": "vscode",
  "privileged": true,
  "postCreateCommand": "uv sync",
  "customizations": {
    "vscode": { "extensions": ["ms-python.python", "charliermarsh.ruff"] }
  }
}
```

Do not include a `workspaceMount`, `runArgs` caps, a clone
`onCreateCommand`, a firewall step, `STOKER_*` env, or commit-signing — the
derive owns those.

## Phase 3: Confirm and write

Show the user the proposed `devcontainer.json` + `Dockerfile` and ask:
"Does this match how you develop the project? Anything to change before I
write them?" Iterate on their feedback.

When the user is happy, use your `Write` tool to write **both**
`.devcontainer/Dockerfile` and `.devcontainer/devcontainer.json` (relative
to the repo root). Write the `devcontainer.json` last so it exists when the
session ends. Do not add a stoker-managed marker — this is a user-owned
file. Once both files are written, end the session (`/exit`) so `stoker
onboard` can finalize and `stoker install` / `stoker upgrade` can derive
the sandbox from your base.
