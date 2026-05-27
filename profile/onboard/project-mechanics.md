# Onboard the project-mechanics skill

You are running on the **host** (outside the stoker devcontainer), as
part of `stoker onboard project-mechanics`. Your job is to interview
the user about how their project is built, tested, and linted, then
write a `.claude/skills/project-mechanics/SKILL.md` file the
profile-shipped phase skills (`stoker-work`, `stoker-fixup`,
`stoker-rebase`) will defer to at runtime.

The user is the authority on their project's mechanics. Stoker
provides no defaults: do not assume `nox`, `pnpm`, `pre-commit`,
`cargo`, `make`, or any specific tooling. Ask, draft, confirm.

## Phase 0: Read the repo to ground your questions

Before asking the user anything, briefly scan the repo so your
questions are pointed:

- `README.md` (and `CONTRIBUTING.md` if present) — usually names the
  primary commands.
- `pyproject.toml` / `package.json` / `Cargo.toml` / `go.mod` /
  `Makefile` / `noxfile.py` / `tox.ini` — anything that hints at
  ecosystem and build entrypoint.
- `.pre-commit-config.yaml` — if present, lint is likely
  `pre-commit run --files {files}` and `pre-commit run --all-files`.
- `.github/workflows/` — what does CI run? Mirror that for the
  full-suite invocations.
- Top-level `tests/` / `src/` / `pkg/` layout to spot monorepos.

If something is obvious from the source (e.g. `pyproject.toml` has
`[tool.pytest.ini_options]`), state it and confirm rather than asking
from scratch ("It looks like you use `pytest` for tests — do you run
it directly, or through `nox -s test`?"). Cite a file path when you
do.

## Phase 1: Interview

Cover, in order:

1. **Ecosystem.** "Which ecosystems live in this repo?" Python, Node /
   TypeScript, Rust, Go, mixed. Note the primary one.
2. **Test commands.**
   - **Focused test (`focused_test`)** — fast invocation that runs ONE
     test or one slice's worth. Prompt: "What's the smallest test
     command you usually run while iterating? Something like `pytest
     -k name` or `nox -s test -- tests/foo_test.py::test_bar` or
     `pnpm vitest run path/to/file.test.ts`?"
   - **Complete test (`complete_test`)** — full suite. Prompt: "What
     do you run before pushing to make sure nothing's broken? The
     same thing CI runs?"
3. **Lint.**
   - **Touched-files lint (`lint_touched`)** — runs over a passed-in
     file list AND must work on untracked files. Prompt: "How do you
     lint a specific list of files (including ones not yet `git
     add`-ed)? `pre-commit run --files {files}` is the usual answer
     in pre-commit-using repos."
   - **Full lint (`lint_all`)** — entire repo. Prompt: "What do you
     run for a full-repo lint pass?"
   - If the project doesn't separate the two, set
     `lint_touched = lint_all` and note that.
4. **Typing (`typing`)** — full static type-check command. May be
   `nox -s typing`, `pnpm typecheck`, `mypy src/`, `tsc --noEmit`,
   `cargo check`, etc. If the project has no static type checker, set
   `typing` to `(none)` and note it.
5. **Final validation.** Walk the user through what
   `complete_test + lint_all + typing` looks like in practice. Ask:
   "Anything else CI runs that should land here? A worker build, a
   docs build, a sub-package's own test suite?" Capture any extras
   prose-style under the `## Final validation` section.
6. **Monorepo selectors (optional).** If the repo is a monorepo
   (multiple workspace packages), ask: "When you change one package,
   how do you scope the test/lint commands to just that package?"
   Capture the routing rules under `## Monorepo selectors`.

Throughout: if the user gives an environment-variable-laden command
(e.g. `TC_HOST=localhost ENV_X=y nox -s test ...`), include the env
vars verbatim — they're load-bearing.

## Phase 2: Draft

Compose the SKILL.md following this exact shape. Headings are H2 and
the command-key names are fixed (`focused_test`, `complete_test`,
`lint_touched`, `lint_all`, `typing`) — the consuming skills cite
them by name:

```markdown
---
name: project-mechanics
description: Project-specific build/test/lint/typing commands for this repo. Read this skill at the start of any phase that runs validation (`stoker-work`, `stoker-fixup`, `stoker-rebase`).
---

# Project mechanics

This file is the source of truth for how this repo runs tests, lint,
and type-checking. Profile-shipped phase skills read it at the start
of each phase and use the named commands verbatim.

## Test commands

- `focused_test`: <fast, single-test or single-slice command>
- `complete_test`: <full suite command>

## Lint

- `lint_touched`: <command that lints a passed-in file list (works on
  untracked files)>
- `lint_all`: <full-repo lint command>

## Typing

- `typing`: <full type-check command>

## Final validation

End-of-task validation runs <complete_test> + <lint_all> + <typing>
in that order. <Mention any sub-package extras: "plus
`cd cloudflare-worker && npm test` for worker changes"; "plus
`uv run --only-group=docs nox -s docs` for docs changes". Omit the
section if there are no extras.>

## Monorepo selectors

<Optional. Per-package routing rules. Omit the section entirely if
the repo isn't a monorepo.>
```

Substitute every `<...>` placeholder with the user-provided values
verbatim. Do not paraphrase commands. Do not add prose around the
bullets unless the user explicitly mentioned a constraint.

## Phase 3: Confirm and write

Show the user the proposed SKILL.md content and ask: "Does this match
how the project actually works? Anything to fix before I write it?"
Iterate on their feedback.

When the user is happy, use your `Write` tool to write the final
SKILL.md content to `.claude/skills/project-mechanics/SKILL.md`
(relative to the repo root). Do NOT include the drift-tracking
footer — `stoker onboard` appends that itself after you exit. Once
the file is written, end the session (`/exit`) so `stoker onboard`
can finalize.
