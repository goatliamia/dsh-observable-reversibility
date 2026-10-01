# What the code says, per candidate (2026-10-01)

Each candidate is recorded the way the project's simplification policy asks for it:
**current owner · effective producer→consumer path · what disappears · what remains · strongest
reason to retain**, then the classification:

- **R** — removal of unreachable behavior;
- **N** — a narrower public behavior, with the loss named;
- **P** — a protected obligation, or insufficient evidence.

---

## A. The session's orientation text has a producer but no value

- **Current owner**: `packages/bundle/web-app/src/index.ts` (`webSurfacePrompt()`), executed for
  sessions created through `dsh web`.
- **Effective path**: web bundle → prompt assembly. The desktop app loads that same bundle
  (`profiles/desktop` bundles = `dsh-base` + `dsh-web-app`), so the value it states — *which
  application carries the session* — is produced nowhere. The file has 0 occurrences of
  `profile`, `desktop`, `Electron`, `boot injection`.
- **What disappears** (proposed): the two statements that are false off the web carrier — the
  `Web GUI` naming and the web-only contract (HMR / `pnpm run dev:web` / "rebuild Web artifacts"
  / `__DSH_BOOT__`) — replaced on desktop by that carrier's own statement.
- **What remains**: for `dsh web` sessions both statements stay exactly as they are; they are
  correct there and useful.
- **Reason to retain the web text**: it carries a real contract (which watcher must run for live
  reload, which entry builds the shell). Generalizing it would lose that.
- **Class**: **N** — a narrower public behavior (the web contract stops being injected where it
  does not hold), with the loss named: desktop sessions lose a sentence that was never true for
  them.

## B. Three internal facts share one public word

- **Current owner**: the profile manifest (`~/.dsh/profiles/<name>/package.json`, keys
  `dsh.profile.bundles` / `dependencies`) decides what loads.
- **Effective path**: manifest → loader → live plugins. Measured here: `desktop` has an empty
  `dependencies` and two bundles; `web` has 37 packages. "Installed" is answered from the
  installer's bookkeeping, "running" from the loader, "usable" from the composition — one word
  covers all three.
- **What disappears**: the unusable choice — a public "installed" that a consumer cannot act on
  without first asking which profile.
- **What remains**: the profile split itself, and its benefit (a broken plugin in one profile
  does not take another's boot down).
- **Reason to retain the split**: boot-time blast radius; it is a real property, not an accident.
- **Class**: **P** for the split (protected), **R** for the gap (an answer no one can read is
  not being used by anything today).

## C. Settings and locks are per profile while the data root is shared

- **Current owner**: the settings document is the active profile's `cordis.patch.yml` (reported
  with evidence in discussion #8399); lock files live per profile.
- **Effective path**: settings editor → Cordis patch → the active profile's document. The data
  root (`$DSH_HOME`: sessions, credentials, workspaces, storage) is shared.
- **What disappears**: the claim "settings are shared" — it is a *global identity claim* that
  nothing can check. What should replace it is the per-consumer claim ("does the value written on
  the CLI side reach this session"), which is checkable.
- **What remains**: the shared data root, deliberately, and per-profile locks.
- **Reason to retain**: isolating executable dependency graphs keeps CLI and desktop from
  changing each other's versions.
- **Class**: **N** — a narrower public statement (replace the identity claim with per-consumer
  claims), loss named: nobody gets to assume the two sides see the same settings.

## D. Uninstall acts on one world

- **Current owner**: the profile that performs the removal.
- **Effective path**: removal → that profile's manifest and links; nothing else is touched.
- **What disappears**: the assumption that one removal is complete (see #3619: several
  workspaces must each be cleaned before the loader stops failing).
- **What remains**: per-profile ownership of activation — which is what makes a single removal
  incomplete in the first place.
- **Reason to retain**: per-profile activation is the same property as B.
- **Class**: **R** — the answer ("which other profiles still hold this") is not being produced
  today by anything.

## E. Two runtime versions read and write one shared data root

- **Current owner**: both carriers — `@deepseek-ai/dsh-desktop 0.2.0-rc.2` (feed
  `download.deepseek.com/dsh-desk/feeds/win-x64/`, channel `nightly`) and the npm-global
  `@deepseek-ai/dsh 0.1.7-rc.2`.
- **Effective path**: either carrier → `$DSH_HOME` → sessions, credentials, storage.
- **What disappears** (proposal): the invisible writer — either the writer identifies itself
  (same lock, version recorded with the write) or the data is not shared.
- **What remains**: the two distributions, whose reason (no system Node/pnpm needed) is sound.
- **Reason to retain**: it is what makes the packaged app work offline out of the box.
- **Class**: **P** — protected distribution decision; the obligation it creates (visible writers)
  is what needs naming.

## F / G. Capability availability mistaken for load policy

- **Current owner**: the composition answers availability (`webServer` present or not); the
  plugin's `inject:` list turns that into a load decision.
- **Effective path**: composition → service presence → dependency injection → plugin state
  (`pending`). The desktop overlay disables some services; plugins that need them stay pending
  (reported in #8028 as six plugins and an incomplete boot).
- **Measured here (2026-10-01), and it contradicts the report**: the live directory offered
  `webServer` and not `webRuntime`; among the plugins installed for the `web` profile, all were
  reachable and exactly one was `optional` — `dsh-better-sidebar`, which injects lazily and is
  therefore not a hard failure. So the capability difference is real (`webRuntime` is absent),
  while the reported hard-failure consequence did not reproduce on this version.
- **What disappears** (proposal): treating availability as policy — a plugin states which
  capabilities it requires, and a composition that lacks one leaves it inactive on that side
  instead of blocking the tree.
- **What remains**: the capability difference itself, which has reasons.
- **Reason to retain**: carriers legitimately provide different capabilities.
- **Class**: **P** for the difference (protected), **N** for the failure mode (narrower: not
  activating beats not booting, loss named: the plugin silently absent on that carrier).

---

## Note on the diagnostic tool

`core/runtime-census/preflight.mjs` supports F/G by answering "can this composition reach this
plugin at all". Per policy, checks of **service presence and plugin metadata are not an invariant
companion** — they compare declarations rather than independently produced observations that can
diverge. It is therefore recorded as a diagnostic, not a guard.
