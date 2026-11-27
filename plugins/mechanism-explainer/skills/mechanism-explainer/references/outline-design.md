# Outline design rules

These are the rules behind `scripts/outline.py` and `templates/outline.html`, and the rules the agent follows when it writes `outline.json`.
Each rule names the value the page uses and the source it comes from.
The page has a light color scheme only, and no dark mode, because the owner of this skill asked for it.

## Structure of the outline

| Rule | Value in the outline | Source |
|---|---|---|
| Share the outline with the person before drafting, and treat it as the story of the document | The outline page opens in a browser, and nothing is written before the person approves it | https://developers.google.com/tech-writing/two/large-docs |
| Put the answer first | The title is followed by its point, and every chapter, page, and section opens with its point in one sentence | https://www.nngroup.com/articles/inverted-pyramid/ and https://digital.gov/guides/plain-language/principles/organize |
| Do not repeat the summary in the text that follows it | `scripts/outline.py` refuses a point written twice | https://guidance.publishing.service.gov.uk/writing-to-gov-uk-standards/writing-guidelines/summaries/ |
| Make headings short, with the key words first, and never a question | Names are short noun headings, and `scripts/outline.py` refuses a name with a question mark | https://guidance.publishing.service.gov.uk/formatting-content/text-formatting/headings/ and https://developers.google.com/style/headings |
| Number only items whose order changes their meaning, such as steps | Chapters, pages, and sections carry no numbers, and `scripts/outline.py` refuses a name that starts with one | https://developers.google.com/tech-writing/one/lists-and-tables and https://www.nngroup.com/articles/presenting-bulleted-lists/ |
| An explanation connects causes, results, and conditions, which a bullet list breaks into pieces | Points are sentences, and `scripts/outline.py` refuses a line that starts with a bullet | https://diataxis.fr/explanation/ and https://www.edwardtufte.com/notebook/lists-design-and-construction-by-edward-tufte/ |
| Show a pair of a term and its explanation as a description list, not a table | Each section is its heading with its point under it, in a `<dl>` | https://developers.google.com/style/tables and https://learn.microsoft.com/en-us/style-guide/scannable-content/lists |
| Keep to three heading levels or fewer | The title, the chapter, and the page are the headings, and a section is a term of a description list | https://digital.gov/guides/plain-language/design/headings |

## Chapter toggles

| Rule | Value on the page | Source |
|---|---|---|
| A toggle must not look like a link | The chapter name is in the body color on a white surface with a border, never in link blue | https://insidegovuk.blog.gov.uk/2021/10/29/how-we-made-the-gov-uk-accordion-component-more-accessible/ |
| Put the open and close icon on the left of the row, and turn it when the row opens | A 28px circled chevron on the left, which turns when the chapter opens | https://smarthr.design/products/components/accordion-panel/ and https://designsystem.digital.gov/components/accordion/ |
| Make the whole row the button, at least 24px high | The whole `summary` row opens the chapter, at least 64px high | https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html and https://design-system.service.gov.uk/components/accordion/ |
| Show the focus | A 3px outline on the focused row and button | https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html |
| Start with every section closed, so the structure shows at a glance | Every chapter starts closed | https://www.nngroup.com/articles/accordions-on-desktop/ and https://design-system.service.gov.uk/components/accordion/ |
| Let several sections be open at once | Each chapter opens on its own, and opening one does not close another | https://www.nngroup.com/articles/accordions-on-desktop/ |
| Offer one control that opens every section, and change its words when they are all open | One button above the chapters, which reads "Open all chapters" and then "Close all chapters" | https://design-system.service.gov.uk/components/accordion/ |
| Use `details` and `summary`, which work without scripts | Each chapter is a `details` element with its row in `summary` | https://design.digital.go.jp/dads/components/accordion/ and https://html.spec.whatwg.org/multipage/interactive-elements.html |
| Open the sections when the page is printed | Every chapter opens before printing, and the button is not printed | https://www.nngroup.com/articles/accordions-on-desktop/ |

## Type and color

| Rule | Value on the page | Source |
|---|---|---|
| Body text at 16px, never under 14px | 16px body, 15px button, nothing smaller | https://design.digital.go.jp/dads/foundations/typography/ and https://smarthr.design/products/design-tokens/typography/ |
| Line height at least 1.5 | 1.6 for English and 1.75 for Japanese | https://www.w3.org/WAI/WCAG22/Understanding/visual-presentation.html and https://www.w3.org/TR/jlreq/ |
| Lines no longer than 80 characters, or 40 for Japanese | Points and the lead are at most `40em` wide | https://www.w3.org/WAI/WCAG22/Understanding/visual-presentation.html and https://www.w3.org/TR/jlreq/ |
| Letter spacing for Japanese at 0 to 0.02em | `0.02em` for Japanese and none for English | https://design.digital.go.jp/dads/foundations/typography/ and https://www.w3.org/TR/jlreq/ |
| Heading sizes step up by about 1.2 to 1.33 | 32px title, 24px chapter, 20px page, 16px bold section | https://smarthr.design/products/design-tokens/typography/ |
| Tell levels apart by size and weight, without decoration | Headings differ in size and weight only | https://www.nngroup.com/articles/visual-hierarchy-ux-definition/ |
| Text contrast of 4.5:1 or more, gray text included | `#1f1f1f` body and `#555555` chapter points on `#ffffff` and `#f6f6f4` | https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html and https://design.digital.go.jp/dads/foundations/color/accessibility/ |
| Group with space first, then a light background, then lines | Space between pages, a tinted panel for the sections, and a line between two sections | https://www.nngroup.com/articles/gestalt-proximity/ and https://smarthr.design/products/design-patterns/spacing-layout-pattern/ |
| A sans-serif font with no thin weights | The system sans-serif, with Hiragino Sans or Noto Sans JP for Japanese, at weights 400 and 700 | https://design.digital.go.jp/dads/foundations/typography/ |
| 16px margins at the sides of a phone screen | 16px side margins under 640px wide | https://smarthr.design/products/design-patterns/spacing-layout-pattern/ |
