# TODO 02 — Convert MS spec .docx → GFM markdown

**Priority:** P0
**Depends on:** — (parallel with 01)
**Status:** pending

## Context

The three Microsoft Open Specifications at `reference-docs/[MS-WMF]-240423.docx`, `[MS-EMF]-240423.docx`, `[MS-EMFPLUS]-240423.docx` are the authoritative source of truth for the binary formats. They are 4–5 MB of OOXML each (110 K words each). Working directly from .docx is painful. We want each top-level chapter (Heading1 paragraph) in its own GFM markdown file under `reference-docs/<spec>/`, with sub-chapters split out when a single chapter exceeds ~10 000 words.

This is a one-shot conversion (re-run only when the spec revision bumps), but it must be reproducible from a script under version control.

## Outcomes

- `scripts/convert_docs.rb` exists, takes a path to a `.docx`, and writes GFM markdown split by Heading1 paragraph to a target directory.
- Running the script against each of the three .docx produces:
  - `reference-docs/ms-wmf/chNN-<slug>.md`
  - `reference-docs/ms-emf/chNN-<slug>.md`
  - `reference-docs/ms-emfplus/chNN-<slug>.md`
- Each file has a YAML frontmatter block with `source:`, `chapter_number:`, `chapter_title:`, `word_count:`.
- Tables (Word `<w:tbl>`) become GFM pipe tables. Numbered lists and bullet lists convert correctly. Code/monospace runs (`<w:rFonts w:ascii="Courier New"/>` or `<w:rStyle w:val="...Code..."/>`) become backticks. Bitfield diagrams (Word text boxes) become fenced code blocks.
- Images in `word/media/` are extracted to `reference-docs/<spec>/media/` and referenced as `![alt](media/imageN.ext)`.
- A `reference-docs/<spec>/INDEX.md` lists each chapter with its title and word count.
- `reference-docs/convert-docs.log` records the source file hash, script version, and timestamp for provenance.

## Files to create

```
scripts/convert_docs.rb              # main script
scripts/docx_to_markdown.rb          # OOXML → GFM renderer (one class per OOXML element family)
spec/scripts/convert_docs_spec.rb    # smoke test against a tiny synthetic .docx
```

## Approach

1. Use `rubyzip` to open the .docx as a Zip::File.
2. Read `word/document.xml`. Parse with `nokogiri`.
3. Walk `<w:body>` children in order: `<w:p>` (paragraph), `<w:tbl>` (table). Preserve order.
4. For each paragraph:
   - Look at `<w:pPr>/<w:pStyle/@w:val>`. If it starts with "Heading1" (or maps to Heading 1 via `word/styles.xml`), split into a new chapter file.
   - Convert runs to inline markdown (bold, italic, code, hyperlink).
   - Map "Heading2".."Heading6" to `##`..`######`.
   - Numbered/bulleted lists from `<w:numPr>` referencing `word/numbering.xml`.
5. For each table:
   - Emit a GFM pipe table. If rowspans or colspans exist, fall back to a fenced HTML block (GFM tables can't do spans).
6. Slugify chapter titles: lowercase, non-alphanumerics → `-`, collapse repeats, max 60 chars.
7. Image extraction: walk `<w:drawing>` or `<w:pict>` → `r:embed` → `word/_rels/document.xml.rels` → `word/media/imageN.ext`. Copy out and rewrite the markdown reference.
8. Write each chapter atomically (temp file + rename).
9. Append to `INDEX.md` after all chapters processed.

## Chapter-size policy

- After splitting by Heading1, walk each chapter's word count.
- If > 10 000 words AND it contains Heading2 sub-sections, split again into `chNN-MM-<slug>.md` per Heading2.
- The chapter index reflects the final granular file list.

## Verification

```bash
bundle exec ruby scripts/convert_docs.rb reference-docs/[MS-EMF]-240423.docx reference-docs/ms-emf/
bundle exec ruby scripts/convert_docs.rb reference-docs/[MS-WMF]-240423.docx reference-docs/ms-wmf/
bundle exec ruby scripts/convert_docs.rb reference-docs/[MS-EMFPLUS]-240423.docx reference-docs/ms-emfplus/

# Sanity checks
ls reference-docs/ms-emf/                  # ~20 files (one per Heading1)
test -f reference-docs/ms-emf/INDEX.md
wc -l reference-docs/ms-emf/*.md           # no file is empty
grep -c "^# " reference-docs/ms-emf/ch01-*.md   # exactly 1 H1 per file
```

Expected chapter counts (approximate; verify against actual):
- MS-EMF: ~20 chapters (sections 1–21 in the spec).
- MS-WMF: ~15 chapters.
- MS-EMFPLUS: ~22 chapters.

## Done when

- [ ] `scripts/convert_docs.rb` runs on all three .docx without errors.
- [ ] Each chapter file has YAML frontmatter.
- [ ] Each chapter file has exactly one H1.
- [ ] INDEX.md exists for each spec with line-per-chapter.
- [ ] `reference-docs/convert-docs.log` is written with provenance.
- [ ] A spot-check of 3 random chapters per spec shows tables, lists, and code runs render correctly.

## Notes

- This script is in `scripts/`, not `lib/`, because it is developer tooling, not shipped with the gem.
- Use `autoload` for the renderer helpers in `scripts/docx_to_markdown.rb`.
- The script must be idempotent — re-running overwrites the same output paths.
- Do not commit the rendered output if it's > 5 MB total; consider .gitignoring `reference-docs/<spec>/media/` and only committing the markdown.
