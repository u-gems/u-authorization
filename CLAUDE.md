# CLAUDE.md

Notes for AI assistants working in `u-authorization`.

## How to work in this repo

### 1. Think before coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity first

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes,
simplify.

### 3. Surgical changes

**Touch only what you must. Clean up only your own mess.**

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.
- Remove imports/variables/functions that _your_ changes orphaned. Don't
  remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-driven execution

**Define success criteria. Loop until verified.**

Turn vague tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step work, state a brief plan with a verification check per step.

---

## What this is

`u-authorization` is a small, zero-runtime-dependency Ruby library for
authorization and role management, living under `lib/micro/authorization/`.
Its public namespace is `Micro::Authorization`, built from three cohesive
pieces:

- **`Permissions`** (`permissions.rb` + `permissions/`) — role-based,
  per-feature permission checks (`to?`, `to_not?`, context matching via
  `Checker` / `ForEachFeature`).
- **`Policy`** (`policy.rb`) — per-subject authorization policies, instantiated
  with a context and the caller's permissions.
- **`Model`** (`model.rb`) — the entry point that ties permissions, policies,
  and a context together (`Model.build`, `#to` / `#policy`, `#map`).

`require 'u-authorization'` (or `require 'micro/authorization'`) loads the lot.
It is a pure-Ruby gem with **no ActiveModel/Rails dependency** — it's designed
to drop into Rails controllers (`[controller_name, action_name]` style
contexts) but doesn't require Rails. Because it's a published gem, behavior
changes — especially anything affecting the public API or the supported `ruby`
matrix — are highly visible.

## Running tests

```bash
bundle exec rake test   # full suite (also the default `rake` task)
```

The suite is plain Minitest with SimpleCov coverage; there are no Appraisals
or ActiveModel axes (the gem has no Rails dependency). `bin/setup` reinstalls
the bundle; `bin/console` opens an IRB session with the gem loaded.

To test across Ruby versions locally, use mise — `.tool-versions` lists the
supported versions. CI (`.github/workflows/ci.yml`) runs the suite across the
full `ruby` matrix (2.7 → head). Tests are the success criterion for any
behavior change — write or update a test first, then make it pass (rule 4).

## README is part of every change

`README.md` is user-facing — keep it in sync with the code. The badges and the
**Required Ruby version** section near the top reference the supported Ruby
bounds; update them when those bounds move. If you change a documented API,
update the relevant **Usage** section in the same commit. (This repo has no
`CHANGELOG.md`.)

## Bumping the version

1. Edit `lib/micro/authorization/version.rb` — change
   `Micro::Authorization::VERSION`. Follow [SemVer](https://semver.org/):
   patch for fixes, minor for additive user-visible changes, major for
   breaking changes.
2. If the supported Ruby matrix moved, update the Ruby badge and the
   **Required Ruby version** section in `README.md`, and double-check the
   `required_ruby_version` in `u-authorization.gemspec` and the CI matrix in
   `.github/workflows/ci.yml` agree.

Don't tag, push, or `gem release` — humans do that.
