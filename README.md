# Mojo-PrettyTidy

Mojo::PrettyTidy is a conservative tidy tool for Mojolicious Embedded Perl templates, especially .html.ep files.

The initial focus is safe normalization and conservative indentation rather than aggressive formatting. Early versions 
aim to preserve template semantics while performing low-risk cleanup.

## Status

Early development.

## Goals

- preserve Mojolicious directives
- normalize whitespace conservatively
- improve readability of .html.ep templates
- support command-line and editor-driven use
- remain safe and predictable

## Non-goals for early versions

- full HTML reformatting
- rewriting Perl expressions
- reflowing text
- magically handling every edge case on day one

## Installation

Development install from the repo:

perl Makefile.PL
make
make test
make install

## Command-line usage
Replace file.html.ep with your template file.

mojo-prettytidy file.html.ep
mojo-prettytidy --check file.html.ep
mojo-prettytidy --diff file.html.ep
mojo-prettytidy --output parsed.file.html.ep file.html.ep
mojo-prettytidy --write file.html.ep
mojo-prettytidy --write --backup file.html.ep
mojo-prettytidy --write --backup --backup-ext=.orig file.html.ep
mojo-prettytidy --stdin < file.html.ep
mojo-prettytidy --version

Notes:

--backup requires --write.
--backup-ext is used with --write --backup.
--output writes the tidied result to a separate file.
--write and --output cannot be used together.
Use --diff to review what would change before rewriting a file.
When rewriting files in place, use --backup to preserve the original first.

## Kate / editor usage

The tool is being designed to work cleanly as an editor-invoked command, similar in spirit to perltidy.

Typical patterns:

script/mojo-prettytidy %filename

or:

script/mojo-prettytidy --stdin

## Current behavior

Current versions perform conservative cleanup and formatting:

- normalize line endings to LF
- remove trailing horizontal whitespace
- ensure a final newline
- apply conservative indentation to obvious HTML-only lines
- indent plain text lines inside safe HTML structure
- preserve lines containing Embedded Perl markers
- handle single-line and multiline HTML comments conservatively
- treat script and style blocks as protected regions
- handle multiline inline style="..." attributes conservatively
- provide --diff for review before rewriting files
- provide --backup and --backup-ext for safer in-place writes

## Perl version

This distribution is currently developed on Perl 5.40.

It may work with lower Perl versions, but that is not currently guaranteed or tested. YMMV.

## License

Same terms as Perl itself.
