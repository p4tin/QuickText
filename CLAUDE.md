# QuickText — Project Instructions

QuickText is a lightweight, high-performance macOS scratchpad app (Apple
Silicon, macOS 15.0+). Full project context now lives in the steering
directory, not in this file.

## Read this first, every time

Before answering any question about this project, or making any change to it,
read all three files in `.claude/steering/`:

* `.claude/steering/product.md` — vision, use cases, the full functional
  requirements baseline, explicit non-goals, and known gaps between spec and
  current implementation.
* `.claude/steering/structure.md` — repository layout, architectural
  boundaries, naming conventions, and known cruft.
* `.claude/steering/tech.md` — stack, dependencies, build commands, coding
  conventions, and hard constraints (no AI features, Silicon-first, RAM budget).

These files are the source of truth for this project's requirements and
conventions and supersede any older summary. If work is happening under
`.claude/designs/{feature-name}/`, also read that feature's
`requirements.md`, `design.md`, and `tasks.md` before touching related code.

## Workflow

This project uses the spec-driven-workflow skill for new features and
non-trivial changes: Steering → Requirements → Design → Tasks → Execute →
Document → Retro. Don't skip straight to code for anything beyond a trivial
fix without going through that flow.
