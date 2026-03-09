# Mojo-PrettyTidy

Mojo::PrettyTidy is a conservative tidy tool for Mojolicious Embedded Perl templates, especially `.html.ep` files.

The initial focus is safe normalization and conservative indentation rather than aggressive formatting. Early versions aim to preserve template semantics while performing low-risk cleanup.

## Status

Early development, but already useful for real-world inspection and iterative cleanup.

## Goals

- preserve Mojolicious template semantics
- normalize whitespace conservatively
- improve readability of `.html.ep` templates
- support command-line and editor-driven use
- remain safe and predictable

## Non-goals for early versions

- full HTML reformatting
- rewriting Perl expressions
- reflowing prose
- prettifying JavaScript
- magically handling every edge case on day one

## Installation

Development install from the repo:

perl Makefile.PL
make
make test
make install

## Command-line usage

Single-file usage:

mojo-prettytidy file.html.ep
mojo-prettytidy --output parsed.file.html.ep file.html.ep
mojo-prettytidy --check file.html.ep
mojo-prettytidy --diff file.html.ep
mojo-prettytidy --write file.html.ep
mojo-prettytidy --write --backup file.html.ep
mojo-prettytidy --write --backup --backup-ext=.orig file.html.ep
mojo-prettytidy --stdin < file.html.ep
mojo-prettytidy --version

Multiple-file usage:

mojo-prettytidy file1.html.ep file2.html.ep --prefix pt.
mojo-prettytidy file1.html.ep file2.html.ep --prefix pt. --outdir parsed

Directory usage:

mojo-prettytidy templates --prefix pt. --outdir parsed

## Multi-file and directory behavior

Positional inputs may be files or directories.

When a positional input is a directory, `mojo-prettytidy` scans it non-recursively and processes matching `.html.ep` files.

When multiple files are processed, use one of:

- `--write` to rewrite files in place
- `--prefix` to write sibling output files with prefixed names
- `--outdir` to write generated files to an output directory

Examples:

mojo-prettytidy templates --prefix pt.
mojo-prettytidy templates --prefix pt. --outdir parsed

This produces files such as:

pt.filename.html.ep
parsed/pt.filename.html.ep

## Option notes

- `--output` is intended for single-file output to a specific file
- `--write` cannot be combined with `--output`, `--prefix`, or `--outdir`
- `--check` and `--diff` require a single input file
- multiple inputs require `--write`, `--prefix`, or `--outdir`

## Kate / editor usage

The tool is designed to work cleanly as an editor-invoked command, similar in spirit to `perltidy`.

Typical patterns:

script/mojo-prettytidy %filename

or:

script/mojo-prettytidy --stdin

For non-destructive inspection of generated output, `--output`, `--prefix`, and `--outdir` are often more useful than `--diff`.

## Current behavior

Current versions perform conservative cleanup:

- normalize line endings to LF
- remove trailing horizontal whitespace
- ensure exactly one trailing newline at end of file
- apply conservative indentation to safe HTML structure
- indent plain text lines inside safe HTML structure
- preserve Embedded Perl structure conservatively
- indent HTML lines containing Embedded Perl markers conservatively
- indent Embedded Perl control lines locally inside surrounding HTML blocks
- indent embedded percent-code lines locally inside surrounding HTML blocks
- handle single-line and multiline HTML comments conservatively
- treat `<script>` and `<style>` blocks as protected regions
- handle multiline opening tags conservatively
- handle multiline inline `style="..."` attributes conservatively

## Design notes

Mojo::PrettyTidy currently favors local readability over aggressive transformation.

In particular, it is intentionally conservative around:

- Embedded Perl control flow
- mixed HTML and Embedded Perl lines
- script and style blocks
- multiline inline attributes
- multiline opening tags

## Perl version

This distribution is currently developed on Perl 5.40.

It may work with lower Perl versions, but that is not currently guaranteed or tested.

## License

Same terms as Perl itself.
