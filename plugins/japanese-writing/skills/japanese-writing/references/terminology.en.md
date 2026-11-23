# Handling terms

This document holds only general principles.
If there is a term list specific to the project, give it priority.

## Principles

1. Adopt terms that are established in the field.
2. Explain a term only at its first use, and keep the same notation after that.
3. For words whose Japanese translation is not standard, use the original word or the established katakana.
4. When a literal translation points to a different concept, do not use that literal translation.

## Which words to drop and which words to use

**The list of words is held by the term list of the repo in use (`CLAUDE.md` / `AGENTS.md` / `GLOSSARY.md`)**.
In a repo with no term list, treat the findings of the upstream `lint.py` and the seven types in 「読み手が何のことか分からない言い回しは、ふだんの言葉に戻す」 ("turn phrasing the reader cannot follow back into everyday words") of the upstream text as grounds for suspicion, and decide from context whether to fix.

Do not copy a table here.
If you copy it, adding a word leaves only one side out of date, and the reader can no longer decide which one is correct.

When you want to drop a word that is not in the list, add one line to the term list of the repo in use.
Before adding it, apply it to existing documents and look at the count, because if you add a word that is used in a correct Japanese sense,
false positives win and the check can no longer be trusted.
