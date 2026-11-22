# Third-party notices

The digital-dashboard plugin ships none of the official files below.
`skills/digital-dashboard/scripts/fetch_official.py` downloads them from their published locations into the user's folder and checks each one against the SHA-256 in `skills/digital-dashboard/references/official-files.json`.
The list records the files as published on 2026-11-22.

## The guidebook and its tools

Source: Digital Agency, Government of Japan, "ダッシュボードデザインの実践ガイドブック" (Practical guidebook for dashboard design), `https://www.digital.go.jp/resources/dashboard-guidebook`.
Terms of use: the Public Data License (PDL) 1.0 (公共データ利用規約（第1.0版）), `https://www.digital.go.jp/resources/open_data/public_data_license_v1.0`, which the site policy of digital.go.jp applies to the site's content unless a page states otherwise.
The policy asks for the source to be credited, as above, and for an edited or processed use to say so and by whom.

| File | Published at | Source and terms |
|---|---|---|
| `guidebook.pdf` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `guidebook-alt.txt` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `manual.pdf` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `worksheet.pptx` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `toolkit.pptx` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `checklist.xlsx` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `summary-format.docx` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `templates/Blue_1_0_0.zip` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `templates/Cyan_1_0_0.zip` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `templates/Green_1_0_0.zip` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `templates/LightBlue_1_0_0.zip` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `templates/Orange_1_0_0.zip` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `templates/Red_1_0_0.zip` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |
| `templates/SolidGray_1_0_0.zip` | digital.go.jp, the guidebook's page | Digital Agency, PDL 1.0 |

## The color themes

Source: Digital Agency, the `policy-dashboard-assets` repository, `https://github.com/digital-go-jp/policy-dashboard-assets`, at commit `a520c070a2c1fb57fdccf8e89e44182110b11a4b` (2026-03-31), folder `powerbi-templates/powerbi-theme-json/`.
Terms of use: the Public Data License (PDL) 1.0, as that repository's README states for its design templates and color themes, with the credit the README describes (a dashboard made by editing them needs no credit; publishing them unedited needs the credit to the guidebook's page on digital.go.jp).

| File | Source and terms |
|---|---|
| `themes/CustomThemeBlueDefault_2026.json` | Digital Agency, PDL 1.0 |
| `themes/CustomThemeCyanDefault_2026.json` | Digital Agency, PDL 1.0 |
| `themes/CustomThemeGreenDefault_2026.json` | Digital Agency, PDL 1.0 |
| `themes/CustomThemeLightBlueDefault_2026.json` | Digital Agency, PDL 1.0 |
| `themes/CustomThemeOrangeDefault_2026.json` | Digital Agency, PDL 1.0 |
| `themes/CustomThemeRedDefault_2026.json` | Digital Agency, PDL 1.0 |
| `themes/CustomThemeSolidGrayDefault_2026.json` | Digital Agency, PDL 1.0 |

## The maps

Source: Digital Agency, the `policy-dashboard-assets` repository, at the same commit, folder `data/map/`.
The polygons were made by the Digital Agency by processing the administrative area data of the National Land Numerical Information (国土数値情報) of the Ministry of Land, Infrastructure, Transport and Tourism.
Terms of use: the terms of the National Land Numerical Information download site, `https://nlftp.mlit.go.jp/ksj/other/agreement.html`, as the repository's README directs.

| File | Source and terms |
|---|---|
| `map/ja_prefecture_area.json` | Digital Agency, from the National Land Numerical Information; its download site's terms |
| `map/ja_municipality_area.json` | Digital Agency, from the National Land Numerical Information; its download site's terms |
| `map/ja_municipality_area_with_pref_boundary.json` | Digital Agency, from the National Land Numerical Information; its download site's terms |

## The rule files of the skill

The files under `skills/digital-dashboard/references/` other than `official-files.json` are written for this plugin by cardene777, based on the guidebook above (Digital Agency, digital.go.jp, PDL 1.0).
They summarize, interpret, and extend its sections in English; they are not the Digital Agency's text, and the Digital Agency did not write or review them.
The color codes in `color-palette.md` come from the guidebook's color palette page, `https://www.digital.go.jp/resources/dashboard-guidebook/color-palette`, and the formatting values in `theme-spec.md` and `chart-library.md` were read from the templates above.
