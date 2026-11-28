# motion-explainer-skill

| Criterion | How to check | Origin |
|---|---|---|
| A reader who asks for reduced motion sees each scene in its end state without movement | `bash plugins/motion-explainer/skills/motion-explainer/tests/test-motion-explainer.sh` check `"reduced motion shows each scene at its end"` passes | #570 #576 |
| At 390 px wide the page has no sideways scroll and the text of a scene is at least 12 px on screen | `bash plugins/motion-explainer/skills/motion-explainer/tests/test-motion-explainer.sh` check `"a phone width has no sideways scroll and readable scene text"` passes | #570 #576 |
| The page reads in light and dark | `bash plugins/motion-explainer/skills/motion-explainer/tests/test-motion-explainer.sh` check `"the page reads in light and dark"` passes | #570 #576 |
| The repository checks pass with the new plugin listed in the marketplace | `bash scripts/check.sh` ends with 0 | #570 |
| The bundled Sakuga VFX core is byte for byte the upstream file at the pinned commit, its MIT license ships next to it, and the page holds it once | `bash plugins/motion-explainer/skills/motion-explainer/tests/test-motion-explainer.sh` check `"the effects core is bundled unmodified with its license"` passes | #576 |
| A reader who asks for reduced motion sees no effect fired, and the speaker still takes each scene's pose | `bash plugins/motion-explainer/skills/motion-explainer/tests/test-motion-explainer.sh` check `"reduced motion fires no effect and still changes poses"` passes | #576 |
| `render` writes one HTML file that loads nothing from the network, with the player first and the figures under it | `bash plugins/motion-explainer/skills/motion-explainer/tests/test-motion-explainer.sh` check `"render writes one offline page with the player first"` passes | #570 #576 |
| `check` refuses part art that loads anything from outside or runs a script | `bash plugins/motion-explainer/skills/motion-explainer/tests/test-motion-explainer.sh` check `"check refuses art that loads from outside or runs a script"` passes | #570 #576 |
