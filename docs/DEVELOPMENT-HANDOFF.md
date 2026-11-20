# Native layout and saved-edit architecture — NomCut Studio

NomCut Studio provides a dedicated cyber-emerald dark interface and a standalone local processing engine built by Nouman Arif. No external clipping services or cloud accounts are required.

## Core Architecture

- `layouts.py`: eleven native layouts, shared preview/export geometry, circular camera mask and layout-aware text placement.
- `/layouts`: supplies geometry to both creation and saved-edit pickers.
- `reedit.py`: open a saved clip and apply edits to one clip or saved clips from the same source URL. Saved source, clip ranges and each clip's own word list are reused. No download, highlight selection or ASR runs in this path.
- `app.py`: persists final word timings, source URL and generation batch. The Clip Vault hides superseded exports while previous files remain available locally.
- `app.js`: Edit clip in the Clip Vault and generated results; eleven-layout picker and speaker size inside the saved editor; one/video apply controls.
- `previews.py`: frame collection remains loading until all four frames are published.
- UI palette is protected against browser auto-dark color overrides; layout cards show actual geometry instead of placeholder symbols.

## Verification

Run `python -m unittest discover -s tests -v` and `node --check app.js`.
