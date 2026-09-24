---
name: plugin-teardown-obligation
description: Use when authoring or reviewing a plugin's unload path — to decide what must be routed through the mediation, what must be declared by name, and what may never be claimed.
---

# The teardown obligation is a judgment, not a promise

A plugin's unload must not be silent. Every resource a plugin acquires belongs to exactly one of three places, and the plugin must say which.

## Route everything you can through the mediation

Register resources inside `apply` with `ctx.effect` / `ctx.on`, and return their cleanup functions. This is the only form the runtime can check: the registration is recorded when the effect runs, and the cleanup you hand back is compared against what the observation shows afterwards.

## Name what you cannot route

Some resources cannot be routed: a file written outside the mediated paths, a spawned process, a message already sent, a value written to `globalThis`. Those cannot be registered — and therefore cannot be undone either. Do not leave them implicit. Name them where the plugin declares itself, together with what they touch:

```js
export const meta = {
  name: 'reporter',
  outOfBand: 'writes ~/.cache/reporter/x.json on load; kept on unload (user data)',
}
```

(The field name is illustrative; the point is that the statement is machine-readable and lives with the plugin, not in prose.) A vague statement is not a declaration: "may leave traces" declares nothing, "writes `<path>`, kept" does.

## What the three verdicts mean to you

| verdict | what happened | what you do |
|---|---|---|
| `verified-reversible` | registration, removal report and snapshots agree | nothing |
| `declared-irreversible` | the run matches the named `outOfBand` statement | nothing — this is a first-class outcome, not a failure |
| `unknown` | the report disagrees with the observation, or nothing was observed | fix the plugin, not the statement |

A declaration never covers a failed cleanup. If something you registered through `ctx.effect` is still there after unload, that is `unknown`, and no statement fixes it.

## Rules

- Route first. Reach for `outOfBand` only for what the mediation cannot hold.
- Never let a resource be neither routed nor named. Silence is the failure this skill exists to prevent.
- Verify disposal for the resources you registered — with a snapshot comparison, not with the fact that `dispose()` returned.
- When reviewing someone else's plugin: ask for the `outOfBand` statement whenever it touches the filesystem, spawns a process, sets a timer outside `ctx`, or writes to `globalThis`. A missing statement is a defect, not a clean plugin.

## Boundary

A verdict is relative to a declared observation surface: these checks compare what that surface shows. They do not see an effect that appears and disappears between two samples, and they do not make a sent message unsent. Widen the surface, or produce a continuous log, if you need those claims.

---

This skill replaces one sentence of `cordis-plugin-development` — *"Verify disposal for resources you add."* That sentence states an obligation with no landing place. The sections above give it one.
