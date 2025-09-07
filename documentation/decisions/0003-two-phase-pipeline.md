\# 0003 – Two-phase pipeline (Extractor → Renderer)

Status: Accepted

Date: 2025-09-06



Context: The monolithic VTT→HTML XSLT mixed parsing and formatting, causing whitespace

regressions and hard-to-test logic.



Decision: Split into

1\. extractor XSLT that emits normalized intermediate XML, and

2\. small renderers for HTML/MD.



Expected Consequences: Parsing centralized once; renderers are simple; easier testing and evolution.

