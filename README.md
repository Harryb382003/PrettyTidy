# Mojo-PrettyTidy

Mojo::PrettyTidy is a conservative tidy tool for Mojolicious Embedded Perl templates, especially .html.ep.

The initial focus is safe normalization and conservative indentation rather than aggressive formatting. Early versions aim to preserve template semantics while performing low-risk cleanup.

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

mojo-prettytidy file.html.ep
mojo-prettytidy --write file.html.ep
mojo-prettytidy --write --backup file.html.ep
mojo-prettytidy --write --backup-ext=.orig --backup file.html.ep
mojo-prettytidy --check file.html.ep
mojo-prettytidy --stdin < file.html.ep
mojo-prettytidy --version

## Kate / editor usage

The tool is being designed to work cleanly as an editor-invoked command, similar in spirit to perltidy.

Typical patterns:

script/mojo-prettytidy %filename

or:

script/mojo-prettytidy --stdin

## Current behavior

Current versions perform conservative cleanup:

When rewriting files in place, use --backup to preserve the original first.

- normalize line endings to LF
- remove trailing horizontal whitespace
- ensure a final newline
- apply a narrow indentation pass to obvious HTML-only lines

## Perl version

This distribution is currently developed on Perl 5.40.

It may work with lower Perl versions, but that is not currently guaranteed or tested. YMMV.

## License

Same terms as Perl itself.

