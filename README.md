# Mojo-PrettyTidy

`Mojo::PrettyTidy` is a conservative tidy tool for Mojolicious
Embedded Perl templates, especially `.html.ep`.

The initial focus is safe normalization and indentation rather than
aggressive formatting. Early versions aim to preserve template
semantics while performing low-risk cleanup such as line-ending
normalization, trailing whitespace removal, and ensuring a final
newline.

## Status

Early development.

## Goals

- preserve Mojolicious directives
- normalize whitespace conservatively
- improve readability of `.html.ep` templates
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

This distribution is developed on Perl 5.40 and currently declares Perl 5.40 as its minimum version. 
It may work on older Perl versions, but that is not currently guaranteed or tested.
