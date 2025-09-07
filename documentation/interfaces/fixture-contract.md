# Fixture contract (v0.1)

## Source of truth (what the extractor emits)

### Root \& namespace
Root element is <vttx> in the namespace urn:vttx:v0.1. The renderer must use this namespace to select nodes. 

### Fixtures
A fixture is emitted as <fixture title="…"> (title is required). Order is the same as the input file. 

A fixture may be empty (no <tc> children), or contain one or more <tc> test cases. Both patterns appear in your file. 

Duplicate titles are allowed (e.g., multiple fixtures titled “Default Session” / “Extended Session”). Consumers must not assume fixture titles are unique. 


#### Element: vttx/vttx/v:fixture

Attributes

@title (string): human fixture title, order preserved from source. Duplicate titles may occur.

Renderer fixture filter:

Input param: fixture (string).

#### Behavior:

If empty/omitted → render all fixtures in document order.

If non-empty → render all fixtures whose normalize-space(@title) matches fixture case-insensitively.

If no match → render a concise notice and list available titles.

Rationale: forgiving matching for CLI convenience; still deterministic.

### Test cases (inside fixtures)
Each <tc> has required attributes: title and id, and three ordered sections:

<prep/>, <body/>, <comp/> (any of them can be empty/self-closed). 

Within those sections, recognized steps (e.g., <wait>) are normalized, and anything not yet mapped is surfaced as <unknown tag="..."/>. This keeps the pipeline lossless while you expand coverage. 



### Timing
Waits are normalized to <wait><ms>…</ms></wait> (milliseconds as integer text). These appear throughout the doc. 

### Functions
.NET/“Net function” calls are captured as:

<netfunc name="…" class="…">
<param type="String"><value>ECU Name</value></param>

…

</netfunc>

(Types and values are preserved; order is significant.) 

## Normalization rules (extractor side)
* Title text: leading/trailing whitespace is trimmed; internal spacing and case are preserved. (Matches what we see in the output.) 
* Ordering: fixtures and test cases keep source order.
* Extensibility: the extractor may add non-breaking attributes later (e.g., slug, index) without changing meanings of existing ones.

## Consumption rules (what the renderer must do)
### Selecting fixtures

The renderer accepts an optional fixture filter (your -Fixture argument).

Exact match, case-sensitive, after trim against @title.

If multiple fixtures have the same title, render all of them in document order.

If no fixtures match, render a short “fixture not found” message and list available titles (to help the user pick one).

If no filter is provided, render all fixtures in document order.

### Rendering fixtures
The renderer must:
* Respect the namespace urn:vttx:v0.1.
* Iterate fixtures that passed the filter (or all if none).
* Inside each <tc>, render sections in the order <prep>, <body>, <comp>.
* Render recognized step kinds (e.g., <wait>) from their normalized form.
* Show <unknown tag="…"/> as a muted “Unknown step: …” to keep the output complete while coverage is expanded.

## Stability / versioning
The namespace acts as the version marker (urn:vttx:v0.1).

Renderer must be forward-tolerant:

Ignore unknown attributes/elements.

Prefer presence checks (\*\[local-name()='…']) under the vttx namespace to remain resilient to extensions.

## Suggested future extensions (non-breaking)
If/when we want more robust fixture addressing without relying on human titles:

Add optional slug: a lowercase, dash-separated title (title="Default Session" slug="default-session").

Add optional index: 1-based position within the document (index="7").

Renderer fallback: if -Fixture doesn’t match any title exactly, match against slug (case-insensitive) before giving up.

These are additive and won’t break existing renderers that only look at @title.