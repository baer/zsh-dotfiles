---
globs: ["editors/*"]
---

- `editors/env.zsh` sets EDITOR='zed' but `system/env.zsh` overrides it to 'code' (alphabetical topic load order). To change the final EDITOR, edit `system/env.zsh`, not this directory.
