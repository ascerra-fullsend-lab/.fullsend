# Workstream Categories

Reference document for the [Fullsend-ai Workstream](https://github.com/orgs/fullsend-ai/projects/1) GitHub project. Each section below defines a workstream category used to classify issues in [fullsend-ai/fullsend](https://github.com/fullsend-ai/fullsend).

These descriptions serve two purposes:

1. **For humans** — clarify scope and boundaries so team members place issues in the right column.
2. **For the classification agent** — provide enough detail to auto-assign a `Workstream Category` to every incoming issue based on its title, body, comments, and labels.

Categories are listed in priority order (left-to-right on the board), as established in the [April 30 planning session](https://docs.google.com/document/d/1mS3u-_Gkz8WvdR3-E1ay-NyOrPiQUWaUieosk0VFSKA/edit). Priority reflects the team's collective vote on what *must* get done — failing on leftmost categories is a team failure; deprioritizing rightmost categories is an acceptable trade-off.

### Classification decision guide

When an issue could plausibly belong in multiple categories, apply these tiebreaker rules in order:

1. **Is it broken right now?** If the issue describes something that is broken, misbehaving, or causing confusion in the currently shipped pipeline for onboarded teams → **Support - MVP Follow-through**, even if the fix involves what looks like a new feature (e.g., adding a missing label, fixing a dispatch trigger, correcting agent output).

2. **Does it touch the admin install/enroll surface?** If the work changes what an org admin does during setup, enrollment, or configuration → **Installer - web/cli**, even if the underlying code is in `internal/scaffold/` or workflow files.

3. **Is it a net-new agent or agent behavior that doesn't exist yet?** A wholly new agent type (secretary, DevOps, classify) or a new action an existing agent has never performed → **New agent capability**. If the agent already does this thing but does it badly → **Support - MVP Follow-through**.

4. **Does it change the runtime contract?** If the issue modifies what tools/runtimes/environments are available to any agent, how harnesses are assembled, or how agents are dispatched → **Agent runtime architecture evolution**.

5. **Does it measure, test, or constrain agent behavior?** Evals, benchmarks, security hardening, test infrastructure, harness schema work → **Agent dev experience, evals + security**.

6. **Is it a `type/chore` or `type/bug` in this repo's developer tooling?** Pre-commit hooks, lint rules, CI fixes, GCP config, release tooling, __pycache__ cleanup → **Agent dev experience, evals + security** (developer experience for fullsend contributors).

7. **When truly ambiguous, leave unclassified** (`null`) rather than guess.

---

## 1. Support - MVP Follow-through

This is the team's non-negotiable top priority. If teams using fullsend are blocked or broken, nothing else matters.

Support covers everything required to keep the current shipped MVP workflow running reliably for all onboarded teams (Konflux, and soon Kaiden and guacsec). The MVP workflow is the [triage→code→review→merge pipeline](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0002-initial-fullsend-design.md) driven by GitHub events, slash commands, and label transitions.

**The key principle:** Support includes not only bug fixes but also **urgent enhancements and fixes to the currently shipped pipeline** — anything that, if left undone, would leave the MVP workflow broken, unreliable, or confusing for onboarded teams. An issue that looks like a "new feature" still belongs here if it fixes a gap in the existing shipped workflow that is causing real problems for real users.

**What belongs here:**

- **Bug fixes and hotfixes** to existing agent behavior — the triage agent ([`triage.yml`](https://github.com/fullsend-ai/fullsend/blob/main/internal/scaffold/fullsend-repo/.github/workflows/triage.yml)), code agent ([`code.yml`](https://github.com/fullsend-ai/fullsend/blob/main/internal/scaffold/fullsend-repo/.github/workflows/code.yml)), fix agent ([`fix.yml`](https://github.com/fullsend-ai/fullsend/blob/main/internal/scaffold/fullsend-repo/.github/workflows/fix.yml)), and review agent ([`review.yml`](https://github.com/fullsend-ai/fullsend/blob/main/internal/scaffold/fullsend-repo/.github/workflows/review.yml))
- **User-reported issues** about agent misbehavior, broken workflows, unexpected output, or enrollment problems
- **Pre/post script fixes** — `post-code.sh`, `post-review.sh`, `post-triage.sh`, `process-fix-result.py`, and their validation/schema enforcement logic. These scripts are the operational glue of the shipped pipeline; bugs here directly affect users: [#411](https://github.com/fullsend-ai/fullsend/issues/411) (force-with-lease), [#412](https://github.com/fullsend-ai/fullsend/issues/412) (fix-result schema validation), [#414](https://github.com/fullsend-ai/fullsend/issues/414) (review not dismissed), [#434](https://github.com/fullsend-ai/fullsend/issues/434) (maxLength enforcement), [#552](https://github.com/fullsend-ai/fullsend/issues/552) (outcome labels not applied)
- **Dispatch and workflow plumbing fixes** — bugs in the shim→.fullsend→agent dispatch chain, concurrency issues, duplicate triggers, confusing job names: [#502](https://github.com/fullsend-ai/fullsend/issues/502) (coder triggered twice), [#460](https://github.com/fullsend-ai/fullsend/issues/460) (duplicate PR when human PR exists), [#573](https://github.com/fullsend-ai/fullsend/issues/573) (dispatch job log links), [#574](https://github.com/fullsend-ai/fullsend/issues/574) (shim dispatch notice), [#575](https://github.com/fullsend-ai/fullsend/issues/575) (rename dispatch jobs), [#551](https://github.com/fullsend-ai/fullsend/issues/551) (Review→Fix dispatch trigger), [#365](https://github.com/fullsend-ai/fullsend/issues/365) (dispatch-review concurrency), [#339](https://github.com/fullsend-ai/fullsend/issues/339) (run_id fallback)
- **Agent output quality issues** visible to end users: [#500](https://github.com/fullsend-ai/fullsend/issues/500) (conflicting test info), [#490](https://github.com/fullsend-ai/fullsend/issues/490) (review agent approving bad PRs), [#567](https://github.com/fullsend-ai/fullsend/issues/567) (bugfix workflow patterns), [#421](https://github.com/fullsend-ai/fullsend/issues/421) (code agent PR description schema)
- **Triage agent operational behavior** — changes to how the existing triage agent works day-to-day: [#561](https://github.com/fullsend-ai/fullsend/issues/561) (drop enhancement category), [#562](https://github.com/fullsend-ai/fullsend/issues/562) (remove enhancement label), [#563](https://github.com/fullsend-ai/fullsend/issues/563) (restore automatic triage), [#581](https://github.com/fullsend-ai/fullsend/issues/581) (disabling triage per-org/repo), [#426](https://github.com/fullsend-ai/fullsend/issues/426) (contextual labeling)
- **Existing agent behavior corrections** that feel like enhancements but fix operational gaps: [#435](https://github.com/fullsend-ai/fullsend/issues/435) (review richer dispositions — currently agents approve bad PRs because they can't "comment-only"), [#464](https://github.com/fullsend-ai/fullsend/issues/464) (label workaround PRs), [#465](https://github.com/fullsend-ai/fullsend/issues/465) (gate wrong-repo PR creation), [#461](https://github.com/fullsend-ai/fullsend/issues/461) (slash command collisions), [#529](https://github.com/fullsend-ai/fullsend/issues/529) (workflow run links), [#450](https://github.com/fullsend-ai/fullsend/issues/450) (fix agent email attribution)
- **Harness timeout and resource issues** in the shipped pipeline: [#288](https://github.com/fullsend-ai/fullsend/issues/288) (TIMEOUT_SECONDS sync), [#534](https://github.com/fullsend-ai/fullsend/issues/534) (separate agent time from dep prep), [#507](https://github.com/fullsend-ai/fullsend/issues/507) (macOS binary in Linux sandbox)
- **Helping specific orgs succeed:** TPA/guac, Vanguard, Konflux-UI, spinmakers — whatever they need to use the fullsend workflow
- Building the CPAS community support model — recruiting fullsend admins from Konflux and Vanguard teams who own installs and monitor the support channel
- Gaining contributors from Red Hat without overloading the core team
- Onboarding support for the [2→20 Konflux repo scale-up](https://docs.google.com/document/d/1RU5G8VPDcAQ-cDTBlVfXUNXwrH6a9EuYgnR2lxFuv4Q/edit) (60-day goal)
- **Upgrades** — managing version upgrades for all onboarded organizations and RH installs management
- **`@ship-help`** — an LLM-powered help bot that uses fullsend docs to answer user questions in-channel, bridging support and docs
- Managing contributor PR volume and triage load
- Cross-repo bug situations where an issue in one repo requires a fix in another
- Issues with labels: `type/bug`, `needs-info`, `ready-to-code` (when they are bug fixes)
- Issues filed by onboarded org users (e.g., @deboer-tim from Kaiden, @gklein, @waynesun09) reporting problems with the shipped workflow

**Distinguishing Support from New agent capability:** The dividing line is *whether the behavior already exists in the shipped pipeline*. If the agent already does something (e.g., reviewing PRs, triaging issues, creating branches) but does it incorrectly, inconsistently, or confusingly → Support - MVP Follow-through. If the behavior is wholly new and has never been shipped (e.g., a secretary agent, a DevOps agent, triage "superseded" close reason) → New agent capability.

**What does NOT belong here:**

- Net-new agent types or capabilities that have never been shipped → [New agent capability](#3-new-agent-capability)
- Install/admin UX improvements → [Installer - web/cli](#2-installer---webcli)
- Documentation improvements → [Documentation, not just for humans anymore](#4-documentation-not-just-for-humans-anymore)
- Research or landscape tasks → uncategorized or [Agent dev experience, evals + security](#5-agent-dev-experience-evals--security)
- Architectural evolution of the runtime/harness/sandbox substrate → [Agent runtime architecture evolution](#6-agent-runtime-architecture-evolution) (unless the issue is directly blocking the shipped pipeline)

---

## 2. Installer - web/cli

Everything an organization administrator touches when setting up, configuring, managing, or removing fullsend. This spans both the browser-based admin web UI and the Go CLI.

**What belongs here:**

- **Admin web UI** — the browser interface hosted via Cloudflare ([ADR 0019](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0019-web-source-and-cloudflare-site-layout.md)) for managing fullsend installations:
  - [#547](https://github.com/fullsend-ai/fullsend/issues/547) trustworthy org listing, [#546](https://github.com/fullsend-ai/fullsend/issues/546) OAuth scoping, [#514](https://github.com/fullsend-ai/fullsend/issues/514) repo onboard/offboard, [#513](https://github.com/fullsend-ai/fullsend/issues/513) install/repair flow, [#512](https://github.com/fullsend-ai/fullsend/issues/512) org hub, [#511](https://github.com/fullsend-ai/fullsend/issues/511) error recovery, [#510](https://github.com/fullsend-ai/fullsend/issues/510) org search, [#509](https://github.com/fullsend-ai/fullsend/issues/509) SPA delivery index
  - [#541](https://github.com/fullsend-ai/fullsend/issues/541) token-at-rest strategy, [#542](https://github.com/fullsend-ai/fullsend/issues/542) non-401 error surfacing, [#543](https://github.com/fullsend-ai/fullsend/issues/543) generic JSON errors for proxy
- **Go CLI** (`cmd/fullsend/`) — the admin commands: install, uninstall, analyze, enroll, unenroll, sync
  - [#453](https://github.com/fullsend-ai/fullsend/issues/453) moving reconcile-repos logic into CLI, [#431](https://github.com/fullsend-ai/fullsend/issues/431) replace hack/patch-fullsend-repo, [#495](https://github.com/fullsend-ai/fullsend/issues/495) all-or-none install UX
- **Config repo (`.fullsend`)** — setup, scaffold deployment ([`internal/scaffold/`](https://github.com/fullsend-ai/fullsend/tree/main/internal/scaffold)), workflow generation, schema validation ([#179](https://github.com/fullsend-ai/fullsend/issues/179))
- **Enrollment** — shim workflows, repo-maintenance workflow, enrollment PRs
  - [#326](https://github.com/fullsend-ai/fullsend/issues/326) empty repo error, [#325](https://github.com/fullsend-ai/fullsend/issues/325) 404 on app install, [#324](https://github.com/fullsend-ai/fullsend/issues/324) PEM secret survival, [#323](https://github.com/fullsend-ai/fullsend/issues/323) uninstall exits early, [#345](https://github.com/fullsend-ai/fullsend/issues/345) commit noise reduction
- **Security of the install surface** — [#505](https://github.com/fullsend-ai/fullsend/issues/505) Turnstile, [#506](https://github.com/fullsend-ai/fullsend/issues/506) hostname alignment, [#420](https://github.com/fullsend-ai/fullsend/issues/420) kill switch
- **Landing page and site** — [#549](https://github.com/fullsend-ai/fullsend/issues/549) product landing page, [#545](https://github.com/fullsend-ai/fullsend/issues/545) CI npm dedup
- **E2e parity** — [#550](https://github.com/fullsend-ai/fullsend/issues/550) browser-based test suite for admin
- Issues with labels: `component/install`
- The [ordered layer model](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0006-ordered-layer-model.md) (ADR 0006), [per-role GitHub Apps](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0007-per-role-github-apps.md) (ADR 0007), [workflow dispatch](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0008-workflow-dispatch-for-cross-repo-dispatch.md) (ADR 0008)

**What does NOT belong here:**

- Agent runtime behavior after installation → [Support - MVP Follow-through](#1-support---mvp-follow-through)
- New agent types or capabilities → [New agent capability](#3-new-agent-capability)
- GitLab/Tekton/Forgejo installer → [Other infrastructure platforms](#7-other-infrastructure-platforms)

---

## 3. New agent capability

Expanding what fullsend agents can do. **Net-new** agent types, wholly new workflows, and new capabilities that have never existed before. This is the "what agents can do" category — not fixing existing behavior (Support) or improving quality/testing (Agent dev).

**The key distinction from Support:** This category is for things that *don't exist yet*. If an existing agent already does something but does it poorly or incompletely, fixing that is Support. If a capability is wholly new — a new agent type, a new close reason, a new kind of action the agent has never performed — it belongs here. Human classifiers consistently put "fix the review agent's disposition options" (an existing agent doing a thing badly) in Support, and "add a secretary agent" (a wholly new agent type) here.

**What belongs here:**

- **New agent types:**
  - Issue categorization agent — auto-classifies incoming issues into workstream categories (this project, see [`gh-classify-agent.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/gh-classify-agent.md))
  - Prioritization agent — a team-internal tool so it's easy to know what to focus on next
  - Backlog effort estimation with AI — rough-sizing open issues automatically
  - [#131](https://github.com/fullsend-ai/fullsend/issues/131) Retro agent / feedback loop into harness (Story 8)
  - [#149](https://github.com/fullsend-ai/fullsend/issues/149) / [#222](https://github.com/fullsend-ai/fullsend/issues/222) Secretary/scribe agent
  - [#329](https://github.com/fullsend-ai/fullsend/issues/329) Per-issue priority scorer, [#330](https://github.com/fullsend-ai/fullsend/issues/330) backlog ranker, [#331](https://github.com/fullsend-ai/fullsend/issues/331) strategic backlog advisor
  - [#371](https://github.com/fullsend-ai/fullsend/issues/371) DevOps agent for CI failure detection
  - [#359](https://github.com/fullsend-ai/fullsend/issues/359) External research tracker, [#358](https://github.com/fullsend-ai/fullsend/issues/358) user feedback tracker
  - Feature refinement and upstreaming workflow (per 60-day goals, TPA/guacsec)
- **New triage capabilities** (actions the triage agent has never performed):
  - Make triage aware of PRs — triage currently only processes issues; extending it to understand and route PRs
  - [#401](https://github.com/fullsend-ai/fullsend/issues/401) Split/decompose multi-concern issues
  - [#469](https://github.com/fullsend-ai/fullsend/issues/469) Handle question-style issues
  - [#281](https://github.com/fullsend-ai/fullsend/issues/281) Already-fixed detection, [#280](https://github.com/fullsend-ai/fullsend/issues/280) not-a-bug rejection
  - [#576](https://github.com/fullsend-ai/fullsend/issues/576) "Superseded" close reason for decomposed issues (a new close action that doesn't exist yet)
  - [#315](https://github.com/fullsend-ai/fullsend/issues/315) Repo contents access for context-aware triage
- **New code/review capabilities** (wholly new behaviors):
  - [#113](https://github.com/fullsend-ai/fullsend/issues/113) Planning phase before implementation
  - [#402](https://github.com/fullsend-ai/fullsend/issues/402) Cross-repo issue creation
  - [#580](https://github.com/fullsend-ai/fullsend/issues/580) Tunable threshold parameters for review conservatism (org admins can't tune review behavior today — this is a new capability)
  - [#369](https://github.com/fullsend-ai/fullsend/issues/369) CI status checking before approval
  - [#370](https://github.com/fullsend-ai/fullsend/issues/370) Supply chain verification in reviews
  - [#85](https://github.com/fullsend-ai/fullsend/issues/85) Implement-review loop before PR submission
- **Workflow features** (net-new interaction patterns):
  - [#553](https://github.com/fullsend-ai/fullsend/issues/553) Slash command context separation (formalizing /code on issues, /fix on PRs)
  - [#422](https://github.com/fullsend-ai/fullsend/issues/422) Label-based agent gating
  - [#313](https://github.com/fullsend-ai/fullsend/issues/313) Cron-based scheduled triggers
  - [#336](https://github.com/fullsend-ai/fullsend/issues/336) Dependency bot PR automation

**Boundary with Support — common mistakes to avoid:** Issues like [#435](https://github.com/fullsend-ai/fullsend/issues/435) (richer review dispositions), [#426](https://github.com/fullsend-ai/fullsend/issues/426) (contextual labeling), [#464](https://github.com/fullsend-ai/fullsend/issues/464) (workaround PR labels), [#465](https://github.com/fullsend-ai/fullsend/issues/465) (gate wrong-repo PRs), [#461](https://github.com/fullsend-ai/fullsend/issues/461) (slash command collisions), and [#272](https://github.com/fullsend-ai/fullsend/issues/272) (emoji reactions) look like new capabilities but are actually improvements to the *existing shipped pipeline* — they fix gaps that cause confusion, wasted CI, or incorrect agent behavior for current users. These belong in **Support - MVP Follow-through**.

**What does NOT belong here:**

- Bug fixes or quality improvements to existing agents → [Support - MVP Follow-through](#1-support---mvp-follow-through)
- Harness/sandbox quality and testing → [Agent dev experience, evals + security](#5-agent-dev-experience-evals--security)
- Platform infrastructure changes → [Agent runtime architecture evolution](#6-agent-runtime-architecture-evolution)

---

## 4. Documentation, not just for humans anymore

Making fullsend understandable, learnable, and navigable for new adopters and existing users. This covers both the documentation content and the systems that deliver it. A key theme from planning: **discoverability** — docs exist but users can't find them; a central place to learn about the project is critical.

**What belongs here:**

- **Discoverability and delivery** — making docs findable, not just writable:
  - [#548](https://github.com/fullsend-ai/fullsend/issues/548) browse and read documentation with embedded mind map
  - A dedicated docs page/site beyond markdown files in the repo
  - `@ship-help` integration — using documentation as the knowledge base for an LLM-powered help bot (bridges [Support - MVP Follow-through](#1-support---mvp-follow-through))
- **User-facing guides** under [`docs/guides/`](https://github.com/fullsend-ai/fullsend/tree/main/docs/guides) per [ADR 0023](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0023-user-documentation-structure.md):
  - [`admin/installation.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/guides/admin/installation.md) — admin install guide
  - [`user/bugfix-workflow.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/guides/user/bugfix-workflow.md) — user bugfix workflow
  - [#419](https://github.com/fullsend-ai/fullsend/issues/419) Power-user config guide
  - [#378](https://github.com/fullsend-ai/fullsend/issues/378) Guide for developing/testing agent definitions
  - [#554](https://github.com/fullsend-ai/fullsend/issues/554) Automated regression test for adding-custom-agents guide
- **Problem documents** — the 19 docs in [`docs/problems/`](https://github.com/fullsend-ai/fullsend/tree/main/docs/problems) covering intent, security, architecture, governance, etc.
- **ADRs** — the 26 records in [`docs/ADRs/`](https://github.com/fullsend-ai/fullsend/tree/main/docs/ADRs) from 0000 (template) through 0025
- **Core docs** — [`vision.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/vision.md), [`roadmap.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/roadmap.md), [`glossary.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/glossary.md), [`architecture.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/architecture.md), [`landscape.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/landscape.md)
- [#455](https://github.com/fullsend-ai/fullsend/issues/455) Onboarding documentation issues
- [#456](https://github.com/fullsend-ai/fullsend/issues/456) Value proposition docs for harness definitions
- [#537](https://github.com/fullsend-ai/fullsend/issues/537) GitHub issue templates with auto-labels
- [#354](https://github.com/fullsend-ai/fullsend/issues/354) Architecture doc updates and ADR filing
- [#146](https://github.com/fullsend-ai/fullsend/issues/146) Branding guidelines
- [#89](https://github.com/fullsend-ai/fullsend/issues/89) GitHub Pages landing page
- Issues with label: `documentation`

**What does NOT belong here:**

- Admin web UI → [Installer - web/cli](#2-installer---webcli)
- Harness definition internals (schemas, enforcement) → [Agent dev experience, evals + security](#5-agent-dev-experience-evals--security)
- Code-level documentation or comments → belongs with the code change itself

---

## 5. Agent dev experience, evals + security

**How WELL agents work** and **the fullsend developer experience itself**. This category covers everything about measuring, testing, and hardening agent behavior — quality, correctness, security posture, and the tooling that makes those things possible. It also includes **this repo's own developer tooling**: pre-commit hooks, lint rules, type checking, CI configuration, release tooling, and repo hygiene chores that don't affect the shipped pipeline but matter for contributors to fullsend itself.

The simplest test: if an issue is about *"are agents doing the right thing?"* or *"can we prove agents are trustworthy?"*, it belongs here. If it's about *"what infrastructure do agents run on?"*, it belongs in [Agent runtime architecture evolution](#6-agent-runtime-architecture-evolution). If it's a `type/chore` or `type/bug` that only affects fullsend developers (not users), it belongs here. Critical for the 60-day goal of [formal Product Security engagement](https://docs.google.com/document/d/1RU5G8VPDcAQ-cDTBlVfXUNXwrH6a9EuYgnR2lxFuv4Q/edit).

**What belongs here:**

- **Eval frameworks** — benchmarks and metrics that measure agent output quality:
  - [#257](https://github.com/fullsend-ai/fullsend/issues/257) SWE-bench or custom benchmark for code agent
  - [#246](https://github.com/fullsend-ai/fullsend/issues/246) RAGAS-based knowledge assessment
  - [#499](https://github.com/fullsend-ai/fullsend/issues/499) opendatahub agent-eval-harness for skill evals
  - [#73](https://github.com/fullsend-ai/fullsend/issues/73) Regression tests/evals for all agents and skills
  - [#350](https://github.com/fullsend-ai/fullsend/issues/350) Evolutionary algorithm optimization of agent configs
  - Related problem doc: [`testing-agents.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/testing-agents.md)
- **Security hardening** — policies, penetration testing, credential isolation, and attack surface reduction. Includes re-evaluating agent harness/sandbox policies to ensure they are not over-permissive (e.g. `disallowedTools` being ignored):
  - [#129](https://github.com/fullsend-ai/fullsend/issues/129) Story 6: Prompt Injection Defense
  - [#174](https://github.com/fullsend-ai/fullsend/issues/174) Reasoning monitor agent for injection detection
  - [#172](https://github.com/fullsend-ai/fullsend/issues/172) Andon cord: org-wide emergency halt
  - [#444](https://github.com/fullsend-ai/fullsend/issues/444), [#445](https://github.com/fullsend-ai/fullsend/issues/445), [#446](https://github.com/fullsend-ai/fullsend/issues/446) Secret redaction bypasses
  - [#265](https://github.com/fullsend-ai/fullsend/issues/265) SSRF/DNS rebinding
  - [#477](https://github.com/fullsend-ai/fullsend/issues/477) Sandbox npm supply chain hardening
  - [#303](https://github.com/fullsend-ai/fullsend/issues/303) disallowedTools migration
  - [#408](https://github.com/fullsend-ai/fullsend/issues/408) HUMAN_INSTRUCTION bash expand
  - [#267](https://github.com/fullsend-ai/fullsend/issues/267) Agent-commit attestations
  - [#159](https://github.com/fullsend-ai/fullsend/issues/159) Workflow security scanning
  - [#367](https://github.com/fullsend-ai/fullsend/issues/367) Access control for slash commands
  - Related: [ADR 0017](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0017-credential-isolation-for-sandboxed-agents.md), [ADR 0025](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0025-provider-credential-delivery-for-sandboxed-agents.md), [`security-threat-model.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/security-threat-model.md)
- **Testing infrastructure** — test suites, e2e frameworks, local sandbox testing for agents and skills:
  - [#289](https://github.com/fullsend-ai/fullsend/issues/289) Behavioral test coverage for pre/post scripts
  - [#346](https://github.com/fullsend-ai/fullsend/issues/346) Functional tests using local OpenShell sandbox
  - [#360](https://github.com/fullsend-ai/fullsend/issues/360) / [#361](https://github.com/fullsend-ai/fullsend/issues/361) Code and review agent dispatch smoke tests
  - [#486](https://github.com/fullsend-ai/fullsend/issues/486) 2FA migration for e2e bot account
  - [#526](https://github.com/fullsend-ai/fullsend/issues/526) Configurable test org
  - Local deployment and testing — mocking GitHub infrastructure to fully test agents locally
- **Harness development** — the schema, validation, and policy layer that constrains agent behavior:
  - [ADR 0022](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0022-harness-level-output-schema-enforcement.md) Output schema enforcement
  - [ADR 0024](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0024-harness-definitions.md) Harness definitions
  - [#236](https://github.com/fullsend-ai/fullsend/issues/236) Protected vs overridable harness fields
  - [#235](https://github.com/fullsend-ai/fullsend/issues/235) Schema versioning for harness files
  - [#237](https://github.com/fullsend-ai/fullsend/issues/237) Skills loading policy
  - [#430](https://github.com/fullsend-ai/fullsend/issues/430) Third-party skill libraries
- **Fullsend repo developer tooling** — chores and fixes that affect contributors to the fullsend codebase itself:
  - [#100](https://github.com/fullsend-ai/fullsend/issues/100) Fix ty pre-commit hook ignores
  - [#405](https://github.com/fullsend-ai/fullsend/issues/405) lint type check failures in main
  - [#423](https://github.com/fullsend-ai/fullsend/issues/423) GCP model enablement across projects
  - [#436](https://github.com/fullsend-ai/fullsend/issues/436) Clean up __pycache__ files
  - [#520](https://github.com/fullsend-ai/fullsend/issues/520) Release title duplication fix
  - [#558](https://github.com/fullsend-ai/fullsend/issues/558) Lint invalid frontmatter keys in agent files
- **Agent quality and correctness** — drift detection, intent validation, hallucination checking:
  - [#302](https://github.com/fullsend-ai/fullsend/issues/302) Agent drift detection
  - [#300](https://github.com/fullsend-ai/fullsend/issues/300) Automated intent tier classification
  - [#301](https://github.com/fullsend-ai/fullsend/issues/301) Intent composition detection
  - [#457](https://github.com/fullsend-ai/fullsend/issues/457) Local agent execution for evaluation
  - [#488](https://github.com/fullsend-ai/fullsend/issues/488) AI agents validating each other's hallucinations
- Issues with labels: `security`, `component/e2e`, `topic/skills`, `sandbox`

**Boundary with Agent runtime architecture evolution:** If the work changes *what LLM/sandbox/orchestrator is available* (infrastructure plumbing), it's Agent runtime architecture evolution. If it *measures, tests, or constrains* agent behavior within the existing infrastructure, it's this category. Example: "add Gemini CLI support" = Agent runtime architecture evolution; "benchmark code agent output quality on Gemini vs Claude" = this category. "Sandbox startup time" = Agent runtime architecture evolution; "sandbox policy is too broad and disallowedTools are being ignored" = this category.

**What does NOT belong here:**

- New agent types or workflows → [New agent capability](#3-new-agent-capability)
- Production operational monitoring → [platform reliability, operations, olly](#8-platform-reliability-operations-olly)
- Sandbox/runtime infrastructure changes → [Agent runtime architecture evolution](#6-agent-runtime-architecture-evolution)

---

## 6. Agent runtime architecture evolution

**What INFRASTRUCTURE agents run on** — the foundational platform substrate. This is the sandbox, the LLM runtimes, the multi-agent orchestration layer, the workflow plumbing, and the harness assembly contract. The simplest test: if an issue changes *what tools/runtimes/environments are available* to agents or *how agents are assembled and dispatched* as a general platform capability, it belongs here. If it *measures or constrains* how well agents perform within the existing infrastructure, it belongs in [Agent dev experience, evals + security](#5-agent-dev-experience-evals--security). See [`architecture.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/architecture.md) for the five-layer execution stack (Dispatch → Infrastructure → Sandbox → Harness → Runtime).

**Boundary with Support:** Many workflow and dispatch issues (concurrency groups, dispatch naming, timeout sync) ended up in Support because they were directly blocking the shipped pipeline. If a workflow/dispatch issue is a bug or gap causing real problems now → Support - MVP Follow-through. If it's an architectural evolution for future capabilities → here. For example, [#339](https://github.com/fullsend-ai/fullsend/issues/339) (run_id fallback) was classified as Support because missing fallback caused broken concurrency in production; similar work that is forward-looking design would go here.

**What belongs here:**

- **Multi-agent orchestration** — the multi-agent stage, composable pipelines, code→review→code loops:
  - [ADR 0018](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0018-scripted-pipeline-for-multi-agent-orchestration.md) Scripted pipeline orchestration
  - [ADR 0020](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0020-composable-single-responsibility-agents-with-individual-sandboxes.md) Composable agents with individual sandboxes
  - [#234](https://github.com/fullsend-ai/fullsend/issues/234) Code→review→code orchestration patterns
  - [#128](https://github.com/fullsend-ai/fullsend/issues/128) Story 5: Review Agent Swarm & Coordinator
  - [#356](https://github.com/fullsend-ai/fullsend/issues/356) Stocks and flows abstraction
- **Expanding agent tool support (multi-LLM/runtime)** — adding and maintaining alternative runtimes so agents aren't locked to a single provider:
  - [#70](https://github.com/fullsend-ai/fullsend/issues/70) Agent runtime decisions
  - [#200](https://github.com/fullsend-ai/fullsend/issues/200) Configurable model field for subagents
  - [#355](https://github.com/fullsend-ai/fullsend/issues/355) Make agent model configurable
  - Gemini CLI support (short-term priority), goose, opencode, Cursor CLI (agent mode)
- **Harness contract evolution** — how agents receive parameters, how pre-scripts signal outcomes, how setup is provisioned:
  - [#579](https://github.com/fullsend-ai/fullsend/issues/579) Design a general parameterization interface for agent runtime configuration
  - [#582](https://github.com/fullsend-ai/fullsend/issues/582) Support graceful pre-script skip (neutral exit code)
  - [#583](https://github.com/fullsend-ai/fullsend/issues/583) Support agent setup scripts for one-time prerequisite provisioning
- **Sandbox evolution** — container/VM performance, per-repo dev environment setup, startup time:
  - [#271](https://github.com/fullsend-ai/fullsend/issues/271) Startup takes 90-120s
  - [#261](https://github.com/fullsend-ai/fullsend/issues/261) Go-native SSH/SCP libraries
  - [#276](https://github.com/fullsend-ai/fullsend/issues/276) Sandbox log collection
  - [#491](https://github.com/fullsend-ai/fullsend/issues/491) Per-repo dev environment discovery
  - [#78](https://github.com/fullsend-ai/fullsend/issues/78) Sandbox layer implementation
  - Easy container/dev environment per-repo (solving the yarn problem and related dependency issues)
- **Workflow architecture** — dispatch, triggers, concurrency, retry, label state machines:
  - [#77](https://github.com/fullsend-ai/fullsend/issues/77) Concurrent agent runs
  - [#76](https://github.com/fullsend-ai/fullsend/issues/76) Agent trigger mechanisms
  - [#335](https://github.com/fullsend-ai/fullsend/issues/335) Workflows for easy agent addition/replacement
  - [#125](https://github.com/fullsend-ai/fullsend/issues/125) Story 2: Entry Point, Label State Machine & Slash Commands
  - [#270](https://github.com/fullsend-ai/fullsend/issues/270) Composite action retry logic
  - (Note: many dispatch bugs like [#339](https://github.com/fullsend-ai/fullsend/issues/339), [#365](https://github.com/fullsend-ai/fullsend/issues/365), [#534](https://github.com/fullsend-ai/fullsend/issues/534) are classified as Support because they directly block the shipped pipeline)
- **Harness assembly** — config layering, precedence, local invocation, rewriting scripts:
  - [#173](https://github.com/fullsend-ai/fullsend/issues/173) Precedence rules, local invocation, pull vs push
  - [#195](https://github.com/fullsend-ai/fullsend/issues/195) Per-repo config overrides
  - [#75](https://github.com/fullsend-ai/fullsend/issues/75) Separate core from org-specific config
  - [#347](https://github.com/fullsend-ai/fullsend/issues/347) Rewriting scripts in Python
  - Rewriting architectural pieces after gaining real-world experience
- **Skill ecosystem** — integrating skills from other RH departments, prodoc skills, third-party skills in the konflux-ci org:
  - [#430](https://github.com/fullsend-ai/fullsend/issues/430) Third-party skill libraries (also relevant to category 5 from a policy/loading perspective)
- Related problem docs: [`agent-infrastructure.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/agent-infrastructure.md), [`agent-architecture.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/agent-architecture.md)

**Boundary with Agent dev experience, evals + security:** If the work *adds, changes, or improves infrastructure plumbing* (a new runtime, faster sandbox, multi-agent pipeline), it's this category. If the work *measures, tests, or constrains behavior* within the existing infrastructure (benchmarks, evals, security policies, test suites), it's Agent dev experience, evals + security. Example: "add goose runtime support" = this category; "test suite verifying agent output quality" = Agent dev experience. "Per-repo dev environment container setup" = this category; "penetration testing the sandbox" = Agent dev experience.

**What does NOT belong here:**

- Specific agent behaviors or new agent types → [New agent capability](#3-new-agent-capability)
- Security policy hardening, evals, or testing → [Agent dev experience, evals + security](#5-agent-dev-experience-evals--security)
- User-facing install experience → [Installer - web/cli](#2-installer---webcli)

---

## 7. Other infrastructure platforms

Breadth of platform support — making fullsend work beyond GitHub Actions + Claude Code. The [forge abstraction layer](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0005-forge-abstraction-layer.md) (ADR 0005) provides the foundation via the `forge.Client` interface.

**What belongs here:**

- **GitLab:**
  - [#322](https://github.com/fullsend-ai/fullsend/issues/322) Add GitLab CI as trigger/coordination/compute layer
  - GitLab `forge.Client` implementation behind the abstraction
  - Cross-forge identity challenges (GitLab lacks GitHub App manifest flow)
- **Tekton / Kubernetes:**
  - Testing fullsend against Tekton pipelines and task-based CI
  - OpenShift Pipelines support
  - Running fullsend on Kubernetes as a compute substrate (not just GitHub Actions runners)
- **Forgejo:**
  - Community forge alternative support
- **Cross-platform testing** — dedicated testing against non-GitHub forges:
  - Test against GitLab (e2e parity with GitHub flows)
  - Test against Tekton (pipeline-based execution)
- **Alternative runtimes** from a platform integration perspective (as distinct from architecture evolution):
  - opencode, cursor-cli, goose — when the work is about making the platform connect to them
- Issues with labels referencing non-GitHub forges or CI systems

**What does NOT belong here:**

- GitHub-specific feature depth → [Installer - web/cli](#2-installer---webcli) or [Agent runtime architecture evolution](#6-agent-runtime-architecture-evolution)
- Agent capabilities → [New agent capability](#3-new-agent-capability)

---

## 8. platform reliability, operations, olly

Making the fullsend platform operationally sound for humans running it at scale. See [`operational-observability.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/operational-observability.md) for the full problem statement.

**What belongs here:**

- **Metrics, cost, and ROI measurement** — answering "is it really making a dent? is it delivering the best we can?" Not just token counts, but whether fullsend is measurably improving developer productivity:
  - [#295](https://github.com/fullsend-ai/fullsend/issues/295) Quality metrics for the autonomous factory
  - [#296](https://github.com/fullsend-ai/fullsend/issues/296) Langfuse deployment vs structured logging
  - [#294](https://github.com/fullsend-ai/fullsend/issues/294) Trace granularity and retention policy
  - Token usage tracking, cost tracking, rework rate measurement
  - SDLC measurement integration — collaborating with P&D's AI adoption effectiveness frameworks (other teams already building measurement capability)
  - Cost governance for community-centric development (per [governance.md](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/governance.md) cost section)
  - Answering the org question: "are we overspending on tokens?" with data
- **Operational reliability:**
  - Runaway detection — review bots reviewing themselves, infinite loops
  - Real-time monitoring for stuck or anomalous agents
  - [ADR 0021](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0021-jsonl-reasoning-trace-exposure.md) JSONL trace exposure and management
  - (Note: [#529](https://github.com/fullsend-ai/fullsend/issues/529) workflow run links was classified as Support because it fixes a gap in the shipped pipeline's user experience)
- **Repo automation:**
  - [#150](https://github.com/fullsend-ai/fullsend/issues/150) Weekly Slack activity summaries
  - [#147](https://github.com/fullsend-ai/fullsend/issues/147) Auto-label PRs by size/paths
  - [#138](https://github.com/fullsend-ai/fullsend/issues/138) Automated changelog generation
  - [#397](https://github.com/fullsend-ai/fullsend/issues/397) Branch prune workflow

**What does NOT belong here:**

- Agent correctness/quality → [Agent dev experience, evals + security](#5-agent-dev-experience-evals--security)
- New capabilities → [New agent capability](#3-new-agent-capability)
- Core architecture → [Agent runtime architecture evolution](#6-agent-runtime-architecture-evolution)

---

## 9. Methods for dealing with scale

Meta-category about how the team handles the inevitable explosion of work items as fullsend scales from a small team project to broad adoption. Not about any specific feature — about the team's capacity to manage the work itself.

**What belongs here:**

- **Backlog management:**
  - The classification agent that auto-assigns workstream categories to incoming issues (this project)
  - Strategies for triaging 200+ open issues and growing
  - [#537](https://github.com/fullsend-ai/fullsend/issues/537) Issue templates to improve categorization at filing time
- **Technical debt and refactoring at scale:**
  - [#347](https://github.com/fullsend-ai/fullsend/issues/347) Evaluate rewriting pre/post/validation scripts in Python
  - [#536](https://github.com/fullsend-ai/fullsend/issues/536) Extract duplicated validation code to shared script
  - [#483](https://github.com/fullsend-ai/fullsend/issues/483) No merge commits policy
  - (Note: individual chores like [#436](https://github.com/fullsend-ai/fullsend/issues/436) __pycache__ cleanup or [#100](https://github.com/fullsend-ai/fullsend/issues/100) pre-commit fixes → Agent dev experience, evals + security)
- **Multi-repo scalability:**
  - Managing deployments across 20+ onboarded repos
  - [#348](https://github.com/fullsend-ai/fullsend/issues/348) enrollment check compares existence not content
- **Process automation:**
  - Automated project management via agents (the "PM agent" concept from planning session)
  - Reducing administrative overhead (milestones, metadata management)
  - Contributor PR tracking dashboard (per planning session next steps)

**What does NOT belong here:**

- Specific bug fixes → [Support - MVP Follow-through](#1-support---mvp-follow-through)
- Specific new features → their respective categories
- Platform compute scaling → [Agent runtime architecture evolution](#6-agent-runtime-architecture-evolution) or [platform reliability, operations, olly](#8-platform-reliability-operations-olly)

---

## Potential new categories

The following clusters of issues don't fit cleanly into the 9 categories above. They may warrant dedicated categories as the project evolves, or they may need explicit routing rules for the classification agent.

### Research & Landscape Evaluation

There are 25+ open issues tagged `research` or `landscape` focused on evaluating external tools, frameworks, and academic work against fullsend's problem space. These are currently homeless:

- [#482](https://github.com/fullsend-ai/fullsend/issues/482) OpenAI Symphony, [#260](https://github.com/fullsend-ai/fullsend/issues/260) OpenHands resolver, [#266](https://github.com/fullsend-ai/fullsend/issues/266) Chatterbox Labs / TrustyAI, [#233](https://github.com/fullsend-ai/fullsend/issues/233) PatchPatrol, [#224](https://github.com/fullsend-ai/fullsend/issues/224) Macaron Software Factory, [#180](https://github.com/fullsend-ai/fullsend/issues/180) Snyk ToxicSkills, [#61](https://github.com/fullsend-ai/fullsend/issues/61) SAFE-MCP, [#538](https://github.com/fullsend-ai/fullsend/issues/538) agentready assessment
- Article reviews: [#57](https://github.com/fullsend-ai/fullsend/issues/57) latent.space on code reviews, [#58](https://github.com/fullsend-ai/fullsend/issues/58) Mitchell Hashimoto / ThoughtWorks, [#60](https://github.com/fullsend-ai/fullsend/issues/60) OpenAI alignment, [#62](https://github.com/fullsend-ai/fullsend/issues/62) multi-agent trap, [#244](https://github.com/fullsend-ai/fullsend/issues/244) Oxide RFD 576, [#255](https://github.com/fullsend-ai/fullsend/issues/255) "Vibes Don't Scale"
- Tool investigations: [#269](https://github.com/fullsend-ai/fullsend/issues/269) Context7, [#297](https://github.com/fullsend-ai/fullsend/issues/297) AST-based code graph indexing

**Current workaround:** Route to Agent dev experience, evals + security if security-focused, to New agent capability if it directly informs a new agent, otherwise leave uncategorized.

**Why it might deserve its own category:** Research is a distinct activity (reading, evaluating, writing findings) from building features or fixing bugs. It informs multiple other categories but doesn't belong in any one of them. The team regularly files research issues and they accumulate in the backlog.

### Governance, Policy & Intent Design

Several problem documents ([`governance.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/governance.md), [`intent-representation.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/intent-representation.md), [`autonomy-spectrum.md`](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/autonomy-spectrum.md)) and related issues represent design-level policy work that doesn't map to any workstream:

- [#300](https://github.com/fullsend-ai/fullsend/issues/300) Automated intent tier classification
- [#301](https://github.com/fullsend-ai/fullsend/issues/301) Intent composition detection
- [#84](https://github.com/fullsend-ai/fullsend/issues/84) Protect org guardrails from per-repo override
- [#334](https://github.com/fullsend-ai/fullsend/issues/334) Definition of done modeling
- [#299](https://github.com/fullsend-ai/fullsend/issues/299) CLAUDE.md size limits and context governance

**Current workaround:** Route to Agent dev experience, evals + security if it's about enforcement tooling, to Documentation if it's about documenting decisions.

### Human Factors & Contributor Experience

The problem docs on [human factors](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/human-factors.md), [contributor guidance](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/contributor-guidance.md), and [contribution volume](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/contribution-volume.md) describe a distinct concern — how humans interact with and alongside the autonomous system:

- [#525](https://github.com/fullsend-ai/fullsend/issues/525) How to spec UI changes for agent-driven development
- [#114](https://github.com/fullsend-ai/fullsend/issues/114) Strip comments from agent input
- [#102](https://github.com/fullsend-ai/fullsend/issues/102) Ensure agent comments can be trusted
- [#258](https://github.com/fullsend-ai/fullsend/issues/258) ACMM dashboard citation, [#249](https://github.com/fullsend-ai/fullsend/issues/249) KubeStellar readiness detection

**Current workaround:** Route to Support - MVP Follow-through if it's about current users, to Documentation if it's about contributor documentation.

### Production Feedback & Downstream Integration

The [production feedback](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/production-feedback.md) and [downstream/upstream](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/downstream-upstream.md) problem docs describe the closed-loop model where production signals drive agent work and downstream business priorities flow into upstream development:

- The entire production feedback closed-loop model (signal→triage→fix→validate)
- [Applied docs for konflux-ci](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/applied/konflux-ci/README.md) — organization-specific considerations
- Onboarding guacsec and kaiden orgs (currently split between Support and this gap)

**Current workaround:** Route to New agent capability if it's about building the feedback-loop agents, to Support - MVP Follow-through if it's about onboarding specific orgs.

### Chores & Housekeeping

Many `type/chore` issues are maintenance tasks (CI fixes, dependency alignment, cleanup) that don't map to any strategic workstream:

- [#544](https://github.com/fullsend-ai/fullsend/issues/544) Go version pin alignment, [#545](https://github.com/fullsend-ai/fullsend/issues/545) npm install dedup, [#423](https://github.com/fullsend-ai/fullsend/issues/423) GCP model enablement, [#232](https://github.com/fullsend-ai/fullsend/issues/232) follow up with Justin on assist-bot
- [#308](https://github.com/fullsend-ai/fullsend/issues/308) Replace dispatch PAT with GitHub App

**Current workaround:** Route to the category most affected by the chore (e.g., install chores → Installer, agent chores → Agent dev experience). If truly generic, route to Methods for dealing with scale.
