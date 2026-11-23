# Glossary

Words this repository uses with one meaning.

| Word | Meaning |
|---|---|
| plugin | A folder under `plugins/` that installs through an agent's plugin command |
| format skill | A skill that holds a document format other skills follow, such as `design-doc` in the `doc-formats` plugin. It writes nothing on its own |
| provider skill | A skill that provides content for other skills through musubi, listed under `provides` in its `musubi.json` |
| consumer skill | A skill that follows content another skill provides, listed under `follows` in its `musubi.json`, and reads it by opening that skill by name |
| flow | A JSON file in `.screen-video/flows/` of a project that lists the steps one video of the `screen-video` plugin shows, with their captions |
| rehearsal | A run of a flow by the `screen-video` plugin that records nothing and stops before the first step that sends something or pays |
| storyboard | The page a rehearsal writes, `storyboard.html`, with a picture, the action, and the caption of each step |
| theme | A JSON file of colours, fonts, and corners that sets how the edited videos of the `screen-video` plugin look: bundled in its `themes/`, or a project's own in `.screen-video/themes/` |
