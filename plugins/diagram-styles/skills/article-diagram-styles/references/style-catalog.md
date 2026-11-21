# The style catalog

The skill ships sixteen built-in styles in `data/built-in-styles.json`, in the same shape as the `families` and `finish_profiles` of a catalog, without images.
The user may keep a style catalog and sample images in one styles folder, `~/.styles/` by default; the catalog is optional.
The plugin ships no sample images and never writes into the folder.
The scripts read another folder only when they are given `--styles <dir>`.

## The built-in styles and the catalog

The styles in use are the built-in styles with the catalog laid over them.

| The catalog writes | What happens |
|---|---|
| A style with a name that is not built in | The style sits beside the built-in styles |
| A style with the name of a built-in style | It replaces the built-in style of the same name: the fields the catalog writes are used, and the fields it leaves out, such as `suits`, stay as built in |
| Only `"status": "retired"` under the name of a built-in style | It takes the built-in style of the same name out of use; `family` and `reference_id` are not needed |
| A family with the name of a built-in family | The catalog's `label` and `description` are used for it |
| An image whose `finish_profile` names a built-in style | The image is a sample of that style. An image's `finish_profile` may name a built-in style without a finish profile of that name in the catalog, and its `family` is the built-in style's family |

Without `~/.styles/style-catalog.json`, the built-in styles are used alone.
A catalog that fails the check is refused; the scripts never fall back to the built-in styles in its place.

```text
~/.styles/
  style-catalog.json                 The catalog, version 2
  diagram-style-samples/<style>/     Sample images as the user first collected them, such as style4/
  style-catalog/<family>/<profile>/  The same images sorted by family and finish profile
  legacy-samples/<style>/            Older samples kept for comparing past records
```

Only `style-catalog.json` is required in that place.
Images may sit in any folder under the styles folder, as long as the catalog names each one.
The style4 rules read the style4 samples from `diagram-style-samples/style4/`.

## Version 2

```json
{
  "schema_version": 2,
  "counts": {"source_registrations": 2, "unique_images": 3},
  "families": {
    "illustrated": {"label": "Illustrated", "description": "Drawn objects carry the figure"}
  },
  "finish_profiles": {
    "pen-technical": {
      "family": "illustrated",
      "label": "Pen technical",
      "status": "active",
      "reference_id": "flow-a",
      "sample_ids": ["flow-a", "pen-c"],
      "line": "black pen with a light wobble",
      "fill": "light teal and orange pencil",
      "background": "white",
      "lettering": "natural handwriting",
      "specification": "references/pen-technical.md"
    }
  },
  "images": [
    {
      "id": "flow-a",
      "family": "illustrated",
      "finish_profile": "pen-technical",
      "path": "style-catalog/illustrated/pen-technical/flow-a.png",
      "sha256": "<SHA-256 of the image>",
      "original_paths": ["diagram-style-samples/style4/flow-a.png"],
      "layouts": ["left-to-right-flow"]
    }
  ]
}
```

| Field | What it holds |
|---|---|
| `schema_version` | `2` |
| `counts.source_registrations` | The number of paths in all `original_paths` together |
| `counts.unique_images` | The number of different `sha256` values in `images` |
| `families.<family>` | A family of styles, with a `label` and a `description` |
| `finish_profiles.<profile>.family` | The family the profile belongs to |
| `finish_profiles.<profile>.status` | `active` for new figures, `candidate` until the user chooses it, or `retired` for reading past records only |
| `finish_profiles.<profile>.reference_id` | The `id` of one image of this profile. Optional for a profile with the name of a built-in style |
| `finish_profiles.<profile>.sample_ids` | Optional. The `id`s of images of this profile that may be used as style references |
| `finish_profiles.<profile>.line`, `fill`, `background`, `lettering` | The written specification of the finish |
| `finish_profiles.<profile>.suits` | Optional. The kinds of figures the style suits, such as `state transitions`; the skill compares them with the article when no style is named |
| `finish_profiles.<profile>.specification` | Optional. A page of this skill with the full specification, such as `references/pen-technical.md` |
| `images[].id` | A unique name of the image |
| `images[].family`, `images[].finish_profile` | The family and the profile the image belongs to; the profile, from the catalog or built in, must belong to the family |
| `images[].path` | The sorted copy of the image, relative to the styles folder |
| `images[].sha256` | The SHA-256 of the image; every file `path` and `original_paths` name has it |
| `images[].original_paths` | The places where the same image was first collected, relative to the styles folder; may be empty |
| `images[].layouts` | One or more layouts the image shows, such as `left-to-right-flow` |

Other fields, such as `label`, `role`, or `approval`, are kept as records and not checked.

## What the check refuses

`python3 scripts/diagram_sample_catalog.py --validate` reads the built-in styles, the catalog, and every image under the styles folder, and exits 1 naming each problem.
Without `~/.styles/style-catalog.json` it checks the built-in styles alone, exits 0, and says that the catalog is missing.

- A folder given with `--styles <dir>` has no `style-catalog.json`
- `schema_version` is not `2`, including a version 1 catalog
- The catalog or a finish profile holds `resources`. Version 1 named a font and a script inside the skill folder there, which cannot be found from the styles folder, so version 2 has no `resources`. The font ships with the skill instead
- A file named by `path` or `original_paths` is missing, lies outside the styles folder, is named twice, or has another SHA-256 than its entry
- A number under `counts` does not match the catalog
- An image file (`.png`, `.webp`, `.jpg`, `.jpeg`) under the styles folder that no `path` or `original_paths` names
- Two images with the same `id` or the same `sha256`, an image without `layouts`, an image whose profile belongs to another family, and a `reference_id` or `sample_ids` entry that names no image of its profile
- An image whose `finish_profile` is neither a built-in style nor in the catalog

A version 1 catalog is not converted. Write it again as version 2: move the image paths so that they are relative to the styles folder, remove every `resources`, and set `schema_version` to `2`.
