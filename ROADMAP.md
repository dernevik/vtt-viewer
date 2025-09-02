# Correctness \& coverage
[] Resolve variable-backed WAIT values: show $Var (12345) when resolvable (local → global) across all shapes, not just common ones. (M)

[] TTFUNC definition lookup hardening: add keys + exact container matches for rare shapes to avoid name collisions. (S)

[] STATECHANGE/STATECHECK parity: ensure both honor the same WAIT/EXPECTED rules and title handling. (S)

[] COMPARE/EXPECTED richness: cover additional operator/rendering cases (ranges, not-equals, valuetables) if present. (M)

[] COMMENT robustness: add fallback to suppress truly empty comments to avoid noise. (S)

# Reviewer UX / output polish
[] Soften “paths” (DBSignal / SysVar / PDU) everywhere they appear (SET/EXPECTED/COMPARE). Keep a safe fallback when the shape is unknown. (M)

[] Consistent spacing: guarantee one space before units (ms, s) in all places (WAIT, AWAITVALUEMATCH, OCCURRENCE\_COUNT, etc.). (S)

[] Inline single WAIT: if a state change has exactly one wait, render WAIT 1000 ms on the same line as the section label; keep a bulleted list if multiple waits. (S)

[] Section semantics: switch list-item headers (Preparation/Steps/Completion) to real headings
```
(<h3>…</h3>)
````
with sibling
```
<ul>
```
for better readability/export. (S)

[] Step numbering / anchors: optional per-TC counters (e.g., 2.4 EXPECTED …) and HTML anchors for easy reference in reviews. (M)

[] Collapsible sections: lightweight CSS/JS to fold/unfold long sections (Preparation/Expected). No framework needed. (M)

[] Error hints: when a definition/variable can’t be resolved, add a muted (unresolved) tag so reviewers know it’s intentional. (S)


# Maintainability / architecture
[] Centralize common logic (partly done): keep helpers like emit-wait-line, bestValueLabel, and future prettyPath as the single sources of truth. (S)

[] Keys for lookups: use xsl:key widely for tc-by-id/name, fn-by-name, var-by-name to avoid // scans and keep selectors tidy. (S)

[] Refactor to 2-stage pipeline (extractor → renderers):

- Stage A: extract a neutral JSON/XML listing (stable schema).

- Stage B: render HTML and Markdown from that intermediate form.

- This keeps HTML+MD in sync and makes future outputs trivial (txt, CSV, etc.). (L)

[] Define a tiny “viewer schema”: document the intermediate structure (Fixture→TC→Sections→Steps), so future code is against our schema, not Vector’s. (M)

# Tooling / DevX
[] Regression tests (golden files): commit 2–3 example VTTs and their expected HTML outputs; add a script to regenerate and diff on PRs. (M)

[] Tiny regression example for NETFUNC under examples. A snippet with a NETFUNC and mixed param types.

[] GitHub Actions: run the transform on samples, fail CI on diffs; optionally validate XML well-formedness. (M)

[] VS Code task: one-click “Render current .vtt → HTML in examples/” (handy for contributors). (S)

# Documentation
[] README improvements: short “Architecture” section (helpers, keys, how fixtures are filtered), and “Contributing” (branching, labels, how to run tests). (S)

[] Examples folder: keep the generic automotive demo VTT + rendered HTML (no internal data); link from README. (S)

[] Style guide note: record the decision to keep units as-is in source (normalization belongs in the team’s authoring style guide, not the viewer). (S)


# Nice-to-haves
[] Plain-text renderer: a very compact listing for Gerrit side-by-side diffs (could be generated via the extractor or a simplified XSL). (M)

[] Fixture / TC filters: already have -Fixture; optionally add -TestCaseId or -Contains "keyword" (PowerShell layer). (S)

[] Auto-open output: param to open the generated HTML after transform (PowerShell layer). (S)

[] Small HTML theme: monospace in code, better contrast, light/dark mode via a tiny CSS. (S)


# Suggested label set (reuse for issues)
* type/enhancement, type/bug, type/refactor, type/docs
* area/xslt, area/html-output, area/parser-semantics, area/tooling
* priority/P1–P3, status/accepted


# Suggested sequencing (low risk → higher impact)
* UX polish: spacing, headings, single-line WAIT, empty-title suppression.
* PrettyPath helper + wire it across SET/EXPECTED.
* Keys + central helpers everywhere (finish consolidation).
* Regression tests + CI.
* Extractor → renderers refactor
* Plain-text renderer and/or VS Code task.