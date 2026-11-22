"""Builds the sample report that the tests open in a browser, from the real template.

Usage: python3 sample_report.py <template> <en|ja> <out.html> [--variant NAME] [--probe FILE]

The report is filled the way references/report-structure.md describes: the facts on the cover, the
picks, the candidate cards with their keys, two axis tables with a bar chart and a long table, the
risks with a caution, the scorecard, the recommendation, and the sources. The Japanese text is kept
as escapes so that this file stays in English.

Each variant changes one thing for the checks of check-report.py and the facts. bad-count, bad-axes,
and bad-sources give a wrong count in the facts; bad-key gives a risk row the key of no card; no-key
leaves the key off the first card; generic-caution names the caution "Risk"; no-author gives no name.
--probe adds the script in FILE at the end of the body, after the template's own script.
"""
import html
import json
import re
import sys

EN = json.loads(r'''{"lang": "en", "title": "Static site generators for the product docs", "eyebrow": "Comparison report", "subtitle": "Quarry, Lumen, and Brisk compared on two axes to choose the generator for the product docs.", "author": "Dana Kim", "contents": "Contents", "toc": [["summary", "Summary"], ["candidates", "Candidates"], ["axis-speed", "Build speed"], ["axis-maintenance", "Maintenance"], ["risks", "Risks"], ["ranking", "Ranking"], ["sources", "Sources"]], "h_summary": "Summary", "reason": "The product docs need a generator that builds the whole site in seconds and costs nothing to host.", "picks": [["Quarry", "The fastest build and no paid plan."], ["Lumen", "A hosted preview for every pull request."], ["Brisk", "A short setup that starts at once."]], "findings": ["Quarry builds the docs in 1.2 s on its own benchmark [1].", "Lumen releases a new version about every two months [3].", "Brisk publishes no price for its hosted plan [5]."], "h_candidates": "Candidates", "cand_caption": "Candidates at a glance", "cand_cols": ["Candidate", "Type", "License", "Releases in 12 months"], "cand_rows": [["Quarry", "Open source", "MIT", "14"], ["Lumen", "Open core", "Apache-2.0", "6"], ["Brisk", "Hosted service", "MIT", "2"]], "field_labels": {"fieldType": "Type", "fieldUsers": "Used by", "fieldStrength": "Strength", "fieldWeakness": "Weakness"}, "cards": [{"key": "quarry", "name": "Quarry", "summary": "A fast generator written in Go.", "type": "Open source", "tag": "t1", "users": "Documentation teams of large open source projects [2]", "strength": "The fastest build of the three [1]", "weakness": "Its templates take time to learn", "description": ["Quarry turns Markdown into a static site with one command.", "It ships as a single binary with no runtime to install.", "Its theme gallery holds about 300 themes [2]."]}, {"key": "lumen", "name": "Lumen", "summary": "A generator with a paid hosted preview.", "type": "Open core", "tag": "t2", "users": "Product teams that review docs in pull requests [3]", "strength": "A preview site for every pull request", "weakness": "The slowest build of the three [4]", "description": ["Lumen builds sites from Markdown and React components.", "Its paid service builds a preview of each pull request.", "The generator itself is free under Apache-2.0."]}, {"key": "brisk", "name": "Brisk", "summary": "A hosted generator with a short guide.", "type": "Hosted service", "tag": "t3", "users": "Small teams without a build server [5]", "strength": "Setup takes one page of instructions", "weakness": "No published price for the hosted plan [5]", "description": ["Brisk hosts the site and builds it on each push.", "Its guide fits on one page.", "The free plan allows one site [6]."]}], "axes": [{"id": "axis-speed", "h2": "Build speed", "caption": "Build time by candidate", "cols": ["Candidate", "Build time (s)", "Score", "Rationale"], "sort": 1, "rows": [["quarry", "Quarry", "1.2", "S", "The fastest of the three on its own benchmark [1]."], ["brisk", "Brisk", "2.9", "B", "More than twice Quarry's time on its own benchmark [6]."], ["lumen", "Lumen", "3.8", "C", "The slowest of the three on its own benchmark [4]."]], "note": "Times from each project's own benchmark, read on 2026-11-09 [1][4][6].", "bars": {"h4": "Build time on its own benchmark (s)", "rows": [["Quarry", 32, "1.2"], ["Brisk Static Site Generator measured on the project's own documentation site with every optional plugin turned on", 76, "2.9"], ["Lumen", 100, "3.8"]]}}, {"id": "axis-maintenance", "h2": "Maintenance", "caption": "Releases by candidate", "cols": ["Candidate", "Releases in 12 months", "Score", "Rationale"], "sort": 1, "rows": [["quarry", "Quarry", "14", "A", "The most releases of the three [2]."], ["lumen", "Lumen", "6", "B", "Fewer than half of Quarry's releases [3]."], ["brisk", "Brisk", "2", "C", "The fewest releases of the three [6]."]], "note": "Release counts from each project's releases page [2][3][6].", "releases": {"caption": "Releases by month", "cols": ["Month", "Quarry", "Lumen", "Brisk"]}}], "legend": [["s", "scoreS", "Outstanding"], ["a", "scoreA", "Strong"], ["b", "scoreB", "Good"], ["c", "scoreC", "Adequate"], ["d", "scoreD", "Weak"]], "h_risks": "Risks", "risk_caption": "Risks by candidate", "risk_cols": ["Candidate", "Risk", "Severity", "Mitigation", "Rationale"], "risk_rows": [["brisk", "Brisk", "No export of the built site", "critical", "Critical", "Keep the Markdown sources in the team's own repository.", "The guide describes no way to download the built site [5]."], ["brisk", "Brisk", "Hosted plan price not published", "high", "High", "Ask for a written price before choosing the hosted plan.", "The hosting page offers a plan without a price [5]."], ["lumen", "Lumen", "Slowest build", "medium", "Medium", "Time a build of the real docs before choosing it.", "It takes 3.8 s on its own benchmark [4]."], ["quarry", "Quarry", "Build time measured only by the project", "low", "Low", "Build the real docs with each candidate on one machine.", "Every build time here comes from each project's own benchmark [1]."]], "caution": {"title": "Brisk keeps the built site on its own servers", "text": "The guide describes no way to download the built site, so moving away means building it again [5]."}, "h_ranking": "Ranking", "score_caption": "Scores on every axis", "score_cols": ["Candidate", "Build speed", "Maintenance", "Cost", "License", "Learning curve", "Rationale"], "score_rows": [["quarry", "Quarry", "S", "A", "S", "S", "A", "First or tied for first on every axis."], ["lumen", "Lumen", "C", "B", "A", "S", "B", "Ahead of Brisk on cost and maintenance."], ["brisk", "Brisk", "B", "C", "-", "S", "C", "Second on build speed but the fewest releases."]], "notscored": "Not scored", "rec_caption": "Recommendation", "rec_cols": ["Recommendation", "Candidate", "When it is the right pick"], "rec_rows": [["First choice", "Quarry", "When the team hosts the built site itself."], ["Alternative", "Lumen", "When every pull request needs a preview."], ["Fallback", "Brisk", "When the team has no build server."]], "h_sources": "Sources", "sources": [["https://quarry.example.org/benchmarks", "Quarry benchmarks", "read 2026-11-09"], ["https://quarry.example.org/releases", "Quarry releases", "read 2026-11-09"], ["https://lumen.example.org/releases", "Lumen releases", "read 2026-11-09"], ["https://lumen.example.org/benchmarks", "Lumen benchmarks", "read 2026-11-09"], ["https://brisk.example.org/hosting", "Brisk hosting", "read 2026-11-08"], ["https://brisk.example.org/guide", "Brisk guide", "read 2026-11-08"]], "footer": "This report reflects public information on the research date."}''')
JA = json.loads(r'''{"lang": "ja", "title": "\u88fd\u54c1\u306e\u6587\u66f8\u306b\u4f7f\u3046\u9759\u7684\u30b5\u30a4\u30c8\u306e\u751f\u6210\u306e\u9053\u5177", "eyebrow": "\u6bd4\u8f03\u306e\u5831\u544a", "subtitle": "\u88fd\u54c1\u306e\u6587\u66f8\u306b\u4f7f\u3046\u9053\u5177\u3092\u9078\u3076\u305f\u3081\u3001Quarry\u3001Lumen\u3001Brisk\u30922\u3064\u306e\u8ef8\u3067\u6bd4\u3079\u305f\u3002", "author": "\u6728\u6751 \u30c0\u30ca", "contents": "\u76ee\u6b21", "toc": [["summary", "\u307e\u3068\u3081"], ["candidates", "\u5019\u88dc"], ["axis-speed", "\u30d3\u30eb\u30c9\u306e\u901f\u3055"], ["axis-maintenance", "\u4fdd\u5b88"], ["risks", "\u30ea\u30b9\u30af"], ["ranking", "\u9806\u4f4d"], ["sources", "\u51fa\u5178"]], "h_summary": "\u307e\u3068\u3081", "reason": "\u88fd\u54c1\u306e\u6587\u66f8\u306b\u306f\u3001\u30b5\u30a4\u30c8\u5168\u4f53\u3092\u6570\u79d2\u3067\u30d3\u30eb\u30c9\u3067\u304d\u3001\u7f6e\u304d\u5834\u306b\u8cbb\u7528\u304c\u304b\u304b\u3089\u306a\u3044\u9053\u5177\u304c\u8981\u308b\u3002", "picks": [["Quarry", "\u30d3\u30eb\u30c9\u304c\u4e00\u756a\u901f\u304f\u3001\u6709\u6599\u306e\u30d7\u30e9\u30f3\u304c\u7121\u3044\u3002"], ["Lumen", "\u30d7\u30eb\u30ea\u30af\u30a8\u30b9\u30c8\u3054\u3068\u306b\u30d7\u30ec\u30d3\u30e5\u30fc\u3092\u4f5c\u308b\u3002"], ["Brisk", "\u624b\u9806\u304c\u77ed\u304f\u3001\u3059\u3050\u306b\u59cb\u3081\u3089\u308c\u308b\u3002"]], "findings": ["Quarry\u306f\u81ea\u524d\u306e\u8a08\u6e2c\u3067\u6587\u66f8\u30921.2\u79d2\u3067\u30d3\u30eb\u30c9\u3059\u308b [1]\u3002", "Lumen\u306f\u7d042\u304b\u6708\u3054\u3068\u306b\u65b0\u3057\u3044\u30d0\u30fc\u30b8\u30e7\u30f3\u3092\u51fa\u3059 [3]\u3002", "Brisk\u306f\u7f6e\u304d\u5834\u306e\u30d7\u30e9\u30f3\u306e\u6599\u91d1\u3092\u51fa\u3057\u3066\u3044\u306a\u3044 [5]\u3002"], "h_candidates": "\u5019\u88dc", "cand_caption": "\u5019\u88dc\u306e\u4e00\u89a7", "cand_cols": ["\u5019\u88dc", "\u7a2e\u985e", "\u30e9\u30a4\u30bb\u30f3\u30b9", "12\u304b\u6708\u306e\u30ea\u30ea\u30fc\u30b9\u6570"], "cand_rows": [["Quarry", "\u30aa\u30fc\u30d7\u30f3\u30bd\u30fc\u30b9", "MIT", "14"], ["Lumen", "\u30aa\u30fc\u30d7\u30f3\u30b3\u30a2", "Apache-2.0", "6"], ["Brisk", "\u30db\u30b9\u30c6\u30a3\u30f3\u30b0", "MIT", "2"]], "field_labels": {"fieldType": "\u7a2e\u985e", "fieldUsers": "\u4f7f\u3063\u3066\u3044\u308b\u4eba", "fieldStrength": "\u5f37\u307f", "fieldWeakness": "\u5f31\u307f"}, "cards": [{"key": "quarry", "name": "Quarry", "summary": "Go\u3067\u66f8\u304b\u308c\u305f\u901f\u3044\u751f\u6210\u306e\u9053\u5177\u3002", "type": "\u30aa\u30fc\u30d7\u30f3\u30bd\u30fc\u30b9", "tag": "t1", "users": "\u5927\u304d\u306a\u30aa\u30fc\u30d7\u30f3\u30bd\u30fc\u30b9\u306e\u6587\u66f8\u306e\u62c5\u5f53\u8005 [2]", "strength": "3\u3064\u306e\u4e2d\u3067\u4e00\u756a\u901f\u3044\u30d3\u30eb\u30c9 [1]", "weakness": "\u30c6\u30f3\u30d7\u30ec\u30fc\u30c8\u3092\u899a\u3048\u308b\u306e\u306b\u6642\u9593\u304c\u304b\u304b\u308b", "description": ["Quarry\u306fMarkdown\u30921\u3064\u306e\u547d\u4ee4\u3067\u9759\u7684\u30b5\u30a4\u30c8\u306b\u3059\u308b\u3002", "\u5b9f\u884c\u74b0\u5883\u3092\u5165\u308c\u306a\u304f\u3066\u3088\u30441\u3064\u306e\u30d0\u30a4\u30ca\u30ea\u3067\u914d\u3089\u308c\u308b\u3002", "\u30c6\u30fc\u30de\u306e\u4e00\u89a7\u306b\u306f\u7d04300\u306e\u30c6\u30fc\u30de\u304c\u3042\u308b [2]\u3002"]}, {"key": "lumen", "name": "Lumen", "summary": "\u6709\u6599\u306e\u30d7\u30ec\u30d3\u30e5\u30fc\u3092\u6301\u3064\u751f\u6210\u306e\u9053\u5177\u3002", "type": "\u30aa\u30fc\u30d7\u30f3\u30b3\u30a2", "tag": "t2", "users": "\u30d7\u30eb\u30ea\u30af\u30a8\u30b9\u30c8\u3067\u6587\u66f8\u3092\u898b\u76f4\u3059\u88fd\u54c1\u306e\u62c5\u5f53\u8005 [3]", "strength": "\u30d7\u30eb\u30ea\u30af\u30a8\u30b9\u30c8\u3054\u3068\u306e\u30d7\u30ec\u30d3\u30e5\u30fc", "weakness": "3\u3064\u306e\u4e2d\u3067\u4e00\u756a\u9045\u3044\u30d3\u30eb\u30c9 [4]", "description": ["Lumen\u306fMarkdown\u3068React\u306e\u90e8\u54c1\u304b\u3089\u30b5\u30a4\u30c8\u3092\u4f5c\u308b\u3002", "\u6709\u6599\u306e\u30b5\u30fc\u30d3\u30b9\u304c\u30d7\u30eb\u30ea\u30af\u30a8\u30b9\u30c8\u3054\u3068\u306b\u30d7\u30ec\u30d3\u30e5\u30fc\u3092\u4f5c\u308b\u3002", "\u751f\u6210\u306e\u9053\u5177\u306fApache-2.0\u3067\u7121\u6599\u3067\u4f7f\u3048\u308b\u3002"]}, {"key": "brisk", "name": "Brisk", "summary": "\u624b\u9806\u306e\u77ed\u3044\u30db\u30b9\u30c6\u30a3\u30f3\u30b0\u306e\u751f\u6210\u306e\u9053\u5177\u3002", "type": "\u30db\u30b9\u30c6\u30a3\u30f3\u30b0", "tag": "t3", "users": "\u30d3\u30eb\u30c9\u306e\u6a5f\u68b0\u3092\u6301\u305f\u306a\u3044\u5c0f\u3055\u306a\u62c5\u5f53\u8005 [5]", "strength": "\u59cb\u3081\u308b\u624b\u9806\u304c1\u9801\u3067\u6e08\u3080", "weakness": "\u7f6e\u304d\u5834\u306e\u30d7\u30e9\u30f3\u306e\u6599\u91d1\u3092\u51fa\u3057\u3066\u3044\u306a\u3044 [5]", "description": ["Brisk\u306f\u30b5\u30a4\u30c8\u3092\u7f6e\u304d\u3001\u9001\u308b\u305f\u3073\u306b\u30d3\u30eb\u30c9\u3059\u308b\u3002", "\u624b\u5f15\u304d\u306f1\u9801\u306b\u53ce\u307e\u308b\u3002", "\u7121\u6599\u306e\u30d7\u30e9\u30f3\u3067\u306f1\u3064\u306e\u30b5\u30a4\u30c8\u3092\u7f6e\u3051\u308b [6]\u3002"]}], "axes": [{"id": "axis-speed", "h2": "\u30d3\u30eb\u30c9\u306e\u901f\u3055", "caption": "\u5019\u88dc\u3054\u3068\u306e\u30d3\u30eb\u30c9\u306e\u6642\u9593", "cols": ["\u5019\u88dc", "\u30d3\u30eb\u30c9\u306e\u6642\u9593 (\u79d2)", "\u8a55\u4fa1", "\u6839\u62e0"], "sort": 1, "rows": [["quarry", "Quarry", "1.2", "S", "3\u3064\u306e\u4e2d\u3067\u4e00\u756a\u901f\u3044 [1]\u3002"], ["brisk", "Brisk", "2.9", "B", "Quarry\u306e2\u500d\u3092\u8d85\u3048\u308b\u6642\u9593\u304c\u304b\u304b\u308b [6]\u3002"], ["lumen", "Lumen", "3.8", "C", "3\u3064\u306e\u4e2d\u3067\u4e00\u756a\u9045\u3044 [4]\u3002"]], "note": "\u6642\u9593\u306f\u5404\u9053\u5177\u306e\u81ea\u524d\u306e\u8a08\u6e2c\u3067\u30012026-11-09\u306b\u8aad\u3093\u3060 [1][4][6]\u3002", "bars": {"h4": "\u81ea\u524d\u306e\u8a08\u6e2c\u306b\u3088\u308b\u30d3\u30eb\u30c9\u306e\u6642\u9593 (\u79d2)", "rows": [["Quarry", 32, "1.2"], ["Brisk Static Site Generator\u3092\u3001\u305d\u306e\u9053\u5177\u306e\u6587\u66f8\u306e\u30b5\u30a4\u30c8\u3067\u5168\u3066\u306e\u8ffd\u52a0\u306e\u6a5f\u80fd\u3092\u5165\u308c\u3066\u6e2c\u3063\u305f\u5834\u5408", 76, "2.9"], ["Lumen", 100, "3.8"]]}}, {"id": "axis-maintenance", "h2": "\u4fdd\u5b88", "caption": "\u5019\u88dc\u3054\u3068\u306e\u30ea\u30ea\u30fc\u30b9", "cols": ["\u5019\u88dc", "12\u304b\u6708\u306e\u30ea\u30ea\u30fc\u30b9\u6570", "\u8a55\u4fa1", "\u6839\u62e0"], "sort": 1, "rows": [["quarry", "Quarry", "14", "A", "3\u3064\u306e\u4e2d\u3067\u4e00\u756a\u591a\u3044 [2]\u3002"], ["lumen", "Lumen", "6", "B", "Quarry\u306e\u534a\u5206\u306b\u5c4a\u304b\u306a\u3044 [3]\u3002"], ["brisk", "Brisk", "2", "C", "3\u3064\u306e\u4e2d\u3067\u4e00\u756a\u5c11\u306a\u3044 [6]\u3002"]], "note": "\u30ea\u30ea\u30fc\u30b9\u306e\u6570\u306f\u5404\u9053\u5177\u306e\u30ea\u30ea\u30fc\u30b9\u306e\u9801\u304b\u3089\u6570\u3048\u305f [2][3][6]\u3002", "releases": {"caption": "\u6708\u3054\u3068\u306e\u30ea\u30ea\u30fc\u30b9", "cols": ["\u6708", "Quarry", "Lumen", "Brisk"]}}], "legend": [["s", "scoreS", "\u3068\u3066\u3082\u826f\u3044"], ["a", "scoreA", "\u826f\u3044"], ["b", "scoreB", "\u307e\u305a\u307e\u305a"], ["c", "scoreC", "\u8db3\u308a\u308b"], ["d", "scoreD", "\u5f31\u3044"]], "h_risks": "\u30ea\u30b9\u30af", "risk_caption": "\u5019\u88dc\u3054\u3068\u306e\u30ea\u30b9\u30af", "risk_cols": ["\u5019\u88dc", "\u30ea\u30b9\u30af", "\u91cd\u3055", "\u5bfe\u7b56", "\u6839\u62e0"], "risk_rows": [["brisk", "Brisk", "\u4f5c\u3063\u305f\u30b5\u30a4\u30c8\u3092\u6301\u3061\u51fa\u305b\u306a\u3044", "critical", "\u91cd\u5927", "Markdown\u306e\u5143\u306e\u6587\u66f8\u3092\u62c5\u5f53\u8005\u306e\u30ea\u30dd\u30b8\u30c8\u30ea\u306b\u7f6e\u3044\u3066\u304a\u304f\u3002", "\u624b\u5f15\u304d\u306b\u4f5c\u3063\u305f\u30b5\u30a4\u30c8\u3092\u30c0\u30a6\u30f3\u30ed\u30fc\u30c9\u3059\u308b\u65b9\u6cd5\u304c\u7121\u3044 [5]\u3002"], ["brisk", "Brisk", "\u7f6e\u304d\u5834\u306e\u30d7\u30e9\u30f3\u306e\u6599\u91d1\u304c\u7121\u3044", "high", "\u9ad8", "\u7f6e\u304d\u5834\u306e\u30d7\u30e9\u30f3\u3092\u9078\u3076\u524d\u306b\u66f8\u9762\u3067\u6599\u91d1\u3092\u805e\u304f\u3002", "\u7f6e\u304d\u5834\u306e\u9801\u306f\u30d7\u30e9\u30f3\u3092\u51fa\u3057\u3066\u3044\u308b\u304c\u6599\u91d1\u3092\u51fa\u3057\u3066\u3044\u306a\u3044 [5]\u3002"], ["lumen", "Lumen", "\u30d3\u30eb\u30c9\u304c\u4e00\u756a\u9045\u3044", "medium", "\u4e2d", "\u9078\u3076\u524d\u306b\u672c\u7269\u306e\u6587\u66f8\u3067\u30d3\u30eb\u30c9\u306e\u6642\u9593\u3092\u6e2c\u308b\u3002", "\u81ea\u524d\u306e\u8a08\u6e2c\u30673.8\u79d2\u304b\u304b\u308b [4]\u3002"], ["quarry", "Quarry", "\u30d3\u30eb\u30c9\u306e\u6642\u9593\u3092\u9053\u5177\u306e\u5074\u3060\u3051\u304c\u6e2c\u3063\u3066\u3044\u308b", "low", "\u4f4e", "1\u3064\u306e\u6a5f\u68b0\u3067\u5404\u9053\u5177\u306b\u672c\u7269\u306e\u6587\u66f8\u3092\u30d3\u30eb\u30c9\u3055\u305b\u308b\u3002", "\u3053\u3053\u306b\u8f09\u305b\u305f\u30d3\u30eb\u30c9\u306e\u6642\u9593\u306f\u5168\u3066\u5404\u9053\u5177\u306e\u81ea\u524d\u306e\u8a08\u6e2c\u306b\u3088\u308b [1]\u3002"]], "caution": {"title": "Brisk\u306f\u4f5c\u3063\u305f\u30b5\u30a4\u30c8\u3092\u81ea\u5206\u306e\u30b5\u30fc\u30d0\u30fc\u306b\u3060\u3051\u7f6e\u304f", "text": "\u624b\u5f15\u304d\u306b\u4f5c\u3063\u305f\u30b5\u30a4\u30c8\u3092\u30c0\u30a6\u30f3\u30ed\u30fc\u30c9\u3059\u308b\u65b9\u6cd5\u304c\u7121\u3044\u306e\u3067\u3001\u79fb\u308b\u6642\u306f\u30b5\u30a4\u30c8\u3092\u4f5c\u308a\u76f4\u3059\u3053\u3068\u306b\u306a\u308b [5]\u3002"}, "h_ranking": "\u9806\u4f4d", "score_caption": "\u5168\u3066\u306e\u8ef8\u306e\u8a55\u4fa1", "score_cols": ["\u5019\u88dc", "\u30d3\u30eb\u30c9\u306e\u901f\u3055", "\u4fdd\u5b88", "\u8cbb\u7528", "\u30e9\u30a4\u30bb\u30f3\u30b9", "\u899a\u3048\u3084\u3059\u3055", "\u6839\u62e0"], "score_rows": [["quarry", "Quarry", "S", "A", "S", "S", "A", "\u5168\u3066\u306e\u8ef8\u30671\u4f4d\u304b1\u4f4d\u306b\u4e26\u3076\u3002"], ["lumen", "Lumen", "C", "B", "A", "S", "B", "\u8cbb\u7528\u3068\u4fdd\u5b88\u3067\u306fBrisk\u3088\u308a\u4e0a\u306b\u3042\u308b\u3002"], ["brisk", "Brisk", "B", "C", "-", "S", "C", "\u30d3\u30eb\u30c9\u306e\u901f\u3055\u306f2\u4f4d\u3060\u304c\u30ea\u30ea\u30fc\u30b9\u304c\u4e00\u756a\u5c11\u306a\u3044\u3002"]], "notscored": "\u8a55\u4fa1\u306a\u3057", "rec_caption": "\u304a\u3059\u3059\u3081", "rec_cols": ["\u304a\u3059\u3059\u3081", "\u5019\u88dc", "\u5408\u3046\u5834\u9762"], "rec_rows": [["\u7b2c\u4e00\u5019\u88dc", "Quarry", "\u4f5c\u3063\u305f\u30b5\u30a4\u30c8\u3092\u62c5\u5f53\u8005\u304c\u81ea\u5206\u3067\u7f6e\u304f\u6642\u3002"], ["\u6b21\u306e\u5019\u88dc", "Lumen", "\u30d7\u30eb\u30ea\u30af\u30a8\u30b9\u30c8\u3054\u3068\u306b\u30d7\u30ec\u30d3\u30e5\u30fc\u304c\u8981\u308b\u6642\u3002"], ["\u6700\u5f8c\u306e\u5019\u88dc", "Brisk", "\u30d3\u30eb\u30c9\u306e\u6a5f\u68b0\u3092\u6301\u305f\u306a\u3044\u6642\u3002"]], "h_sources": "\u51fa\u5178", "sources": [["https://quarry.example.org/benchmarks", "Quarry\u306e\u8a08\u6e2c", "2026-11-09\u306b\u8aad\u3093\u3060"], ["https://quarry.example.org/releases", "Quarry\u306e\u30ea\u30ea\u30fc\u30b9", "2026-11-09\u306b\u8aad\u3093\u3060"], ["https://lumen.example.org/releases", "Lumen\u306e\u30ea\u30ea\u30fc\u30b9", "2026-11-09\u306b\u8aad\u3093\u3060"], ["https://lumen.example.org/benchmarks", "Lumen\u306e\u8a08\u6e2c", "2026-11-09\u306b\u8aad\u3093\u3060"], ["https://brisk.example.org/hosting", "Brisk\u306e\u7f6e\u304d\u5834", "2026-11-08\u306b\u8aad\u3093\u3060"], ["https://brisk.example.org/guide", "Brisk\u306e\u624b\u5f15\u304d", "2026-11-08\u306b\u8aad\u3093\u3060"]], "footer": "\u3053\u306e\u5831\u544a\u306f\u3001\u8abf\u3079\u305f\u65e5\u306e\u516c\u958b\u306e\u60c5\u5831\u3092\u5143\u306b\u3057\u3066\u3044\u308b\u3002"}''')
FACTS = {"CANDIDATE_COUNT": "3", "AXIS_COUNT": "2", "SOURCE_COUNT": "6", "DATE": "2026-11-10"}


def esc(text):
    return html.escape(text, quote=True)


def head_cells(cols, sort=None, direction="ascending"):
    cells = []
    for i, (cls, text) in enumerate(cols):
        attrs = ' scope="col"' + (' class="%s"' % cls if cls else "")
        if sort == i:
            attrs += ' aria-sort="%s"' % direction
        cells.append("<th%s>%s</th>" % (attrs, esc(text)))
    return "".join(cells)


def table(caption, cols, rows, sort=None, direction="ascending"):
    return ('<div class="table-wrap"><table><caption>%s</caption><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>'
            % (esc(caption), head_cells(cols, sort, direction), "".join(rows)))


def score(letter, s):
    if letter == "-":
        return '<td class="center">%s</td>' % esc(s["notscored"])
    return '<td class="center"><span class="score %s">%s</span></td>' % (letter.lower(), letter)


def lines(parts, s):
    return ("<br>" if s["lang"] == "ja" else " ").join(esc(p) for p in parts)


def build(s, variant):
    toc = "".join('<li><a href="#%s">%s</a></li>' % (i, esc(t)) for i, t in s["toc"])
    places = ["gold", "silver", "bronze"]
    picks = "".join('<li class="pick %s"><span class="place">%d</span><h3>%s</h3><p>%s</p></li>' % (places[n], n + 1, esc(name), esc(why))
                    for n, (name, why) in enumerate(s["picks"]))
    findings = "".join("<li>%s</li>" % esc(f) for f in s["findings"])
    summary = '<h2>%s</h2><p>%s</p><ol class="picks">%s</ol><ul class="findings">%s</ul>' % (esc(s["h_summary"]), esc(s["reason"]), picks, findings)

    cand_rows = ['<tr data-candidate="%s"><th scope="row" class="short">%s</th><td class="short">%s</td><td class="short">%s</td><td class="num">%s</td></tr>'
                 % (c["key"], esc(r[0]), esc(r[1]), esc(r[2]), esc(r[3])) for c, r in zip(s["cards"], s["cand_rows"])]
    cols = s["cand_cols"]
    candidates_table = table(s["cand_caption"], [("short", cols[0]), ("short", cols[1]), ("short", cols[2]), ("num", cols[3])], cand_rows)
    labels = s["field_labels"]
    cards = []
    for n, c in enumerate(s["cards"]):
        key = "" if variant == "no-key" and n == 0 else ' data-candidate="%s"' % c["key"]
        fields = "".join('<dt data-t="%s">%s</dt><dd>%s</dd>' % (k, esc(labels[k]), v) for k, v in (
            ("fieldType", '<span class="tag %s">%s</span>' % (c["tag"], esc(c["type"]))), ("fieldUsers", esc(c["users"])),
            ("fieldStrength", esc(c["strength"])), ("fieldWeakness", esc(c["weakness"]))))
        cards.append('<li class="card"%s><h3>%s</h3><p class="summary">%s</p><dl>%s</dl><p>%s</p></li>'
                     % (key, esc(c["name"]), esc(c["summary"]), fields, lines(c["description"], s)))
    candidates = '<h2>%s</h2>%s<ul class="cards">%s</ul>' % (esc(s["h_candidates"]), candidates_table, "".join(cards))

    legend = '<div class="legend">%s</div>' % "".join('<span><span class="score %s">%s</span><span data-t="%s">%s</span></span>'
                                                      % (cls, cls.upper(), key, esc(word)) for cls, key, word in s["legend"])
    axes = []
    for n, axis in enumerate(s["axes"]):
        cols = axis["cols"]
        rows = ['<tr data-candidate="%s"><th scope="row" class="short">%s</th><td class="num">%s</td>%s<td class="rationale">%s</td></tr>'
                % (key, esc(name), esc(value), score(letter, s), esc(why)) for key, name, value, letter, why in axis["rows"]]
        body = table(axis["caption"], [("short", cols[0]), ("num", cols[1]), ("center", cols[2]), ("rationale", cols[3])], rows,
                     sort=axis["sort"], direction="ascending" if n == 0 else "descending")
        if n == 0:
            body += legend
        body += '<p class="note">%s</p>' % esc(axis["note"])
        if "bars" in axis:
            bars = "".join('<div class="bar"><span class="label">%s</span><span class="track"><span class="fill" style="width: %d%%"></span></span><span class="value">%s</span></div>'
                           % (esc(label), width, esc(value)) for label, width, value in axis["bars"]["rows"])
            body += '<div class="bars"><h4>%s</h4>%s</div>' % (esc(axis["bars"]["h4"]), bars)
        if "releases" in axis:
            months = ["%d-%02d" % (2024 + (5 + i) // 12, (5 + i) % 12 + 1) for i in range(30)]
            rows = ['<tr><th scope="row" class="short">%s</th>%s</tr>' % (m, "".join('<td class="num">%d</td>' % ((i * 7 + k * 3) % 3) for k in range(3)))
                    for i, m in enumerate(months)]
            rc = axis["releases"]["cols"]
            body += table(axis["releases"]["caption"], [("short", rc[0]), ("num", rc[1]), ("num", rc[2]), ("num", rc[3])], rows)
        axes.append('<section id="%s" class="chapter axis"><h2>%s</h2>%s</section>' % (axis["id"], esc(axis["h2"]), body))

    cols = s["risk_cols"]
    risk_rows = []
    for n, (key, name, risk, level, word, fix, why) in enumerate(s["risk_rows"]):
        if variant == "bad-key" and n == 0:
            key = "zephyr"
        risk_rows.append('<tr data-candidate="%s"><th scope="row" class="short">%s</th><td>%s</td><td class="short"><span class="risk %s">%s</span></td><td>%s</td><td class="rationale">%s</td></tr>'
                         % (key, esc(name), esc(risk), level, esc(word), esc(fix), esc(why)))
    caution_title = "Risk" if variant == "generic-caution" else s["caution"]["title"]
    risks = '<h2>%s</h2>%s<div class="caution"><h3>%s</h3><p>%s</p></div>' % (
        esc(s["h_risks"]), table(s["risk_caption"], [("short", cols[0]), ("", cols[1]), ("short", cols[2]), ("", cols[3]), ("rationale", cols[4])],
                                 risk_rows, sort=2, direction="descending"), esc(caution_title), esc(s["caution"]["text"]))

    cols = s["score_cols"]
    score_rows = ['<tr data-candidate="%s"><th scope="row" class="short">%s</th>%s<td class="rationale">%s</td></tr>'
                  % (r[0], esc(r[1]), "".join(score(letter, s) for letter in r[2:7]), esc(r[7])) for r in s["score_rows"]]
    rec_rows = ['<tr><th scope="row" class="short">%s</th><td class="short">%s</td><td>%s</td></tr>' % tuple(esc(x) for x in r) for r in s["rec_rows"]]
    rc = s["rec_cols"]
    ranking = '<h2>%s</h2>%s%s' % (
        esc(s["h_ranking"]),
        table(s["score_caption"], [("short", cols[0])] + [("center", c) for c in cols[1:6]] + [("rationale", cols[6])], score_rows),
        table(s["rec_caption"], [("short", rc[0]), ("short", rc[1]), ("", rc[2])], rec_rows))
    sources = '<h2>%s</h2><ol class="sources">%s</ol>' % (esc(s["h_sources"]), "".join(
        '<li><a href="%s">%s</a> <span class="accessed">%s</span></li>' % (url, esc(title), esc(read)) for url, title, read in s["sources"]))

    values = dict(FACTS)
    wrong = {"bad-count": ("CANDIDATE_COUNT", "4"), "bad-axes": ("AXIS_COUNT", "3"), "bad-sources": ("SOURCE_COUNT", "5")}
    if variant in wrong:
        values[wrong[variant][0]] = wrong[variant][1]
    values.update({
        "LANG": s["lang"], "TITLE": esc(s["title"]), "EYEBROW": esc(s["eyebrow"]), "SUBTITLE": esc(s["subtitle"]),
        "AUTHOR": "" if variant == "no-author" else esc(s["author"]), "STATS": "", "CONTENTS_HEADING": esc(s["contents"]),
        "TOC": toc, "SUMMARY": summary, "CANDIDATES": candidates, "AXES": "".join(axes), "RISKS": risks, "RANKING": ranking,
        "SOURCES": sources, "FOOTER": esc(s["footer"]),
    })
    return values


def main():
    args = sys.argv[1:]
    variant, probe = "", ""
    if "--variant" in args:
        i = args.index("--variant")
        variant = args[i + 1]
        del args[i:i + 2]
    if "--probe" in args:
        i = args.index("--probe")
        probe = args[i + 1]
        del args[i:i + 2]
    template, lang, out = args
    values = build(EN if lang == "en" else JA, variant)
    text = open(template, encoding="utf-8").read()
    text = re.sub(r"\{\{([A-Z_]+)\}\}", lambda m: values.get(m.group(1), ""), text)
    if probe:
        end = text.rindex("</body>")
        text = text[:end] + "<script>\n" + open(probe, encoding="utf-8").read() + "\n</script>\n" + text[end:]
    open(out, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    main()
