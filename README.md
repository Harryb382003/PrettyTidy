# Mojo::PrettyTidy

Mojo::PrettyTidy is a conservative formatter for Mojolicious Embedded Perl
templates, especially `.html.ep` files.

It focuses on making template source easier to read without trying to become a
general-purpose HTML formatter, JavaScript formatter, or browser-source cleanup
tool.

## Scope

This tool formats Mojolicious template source that is intended to be rendered by
a Mojolicious application.

It is not intended for downloaded browser source, saved web pages, scraper
output, or other already-rendered HTML documents. You can try that if you really
want to, but that monkey is not a member of this circus.

## Install

From the project root:


perl Makefile.PL
make
make test
make install


## Basic use

Print formatted output to standard output:


mojo-prettytidy templates/example.html.ep


Check whether a file would change:


mojo-prettytidy --check templates/example.html.ep


Write changes back to the file:


mojo-prettytidy --write templates/example.html.ep


Read from standard input and write to standard output:


cat templates/example.html.ep | mojo-prettytidy --stdin


## Common options


mojo-prettytidy --diff templates/example.html.ep
mojo-prettytidy --write --backup templates/example.html.ep
mojo-prettytidy --cols 80 templates/example.html.ep
mojo-prettytidy --no-javascript templates/example.html.ep
mojo-prettytidy --no-perl templates/example.html.ep
mojo-prettytidy -V templates/example.html.ep
mojo-prettytidy -VV templates/example.html.ep


`--cols` is conservative. It currently packs long `style="..."` attributes; it
does not hard-wrap arbitrary prose, Perl expressions, JavaScript, or quoted
payloads.

## Configuration

`mojo-prettytidy` can load defaults from a JSON config file.

If `--config` is not given, it looks for the first available file in this order:

1. `$HOME/.mojo-prettytidy.json`
2. `./.mojo-prettytidy.json`

Command-line options override config values.

## Documentation

The full manual is maintained in:

text
Manual.pod


After installation, use:


perldoc Mojo::PrettyTidy::Manual


The command-line help remains available through:


mojo-prettytidy --help
mojo-prettytidy --man


## Development

Run the test suite with:


prove -lv t


The formatter is intentionally conservative. New behavior should generally be
covered by focused tests before it becomes part of the default output policy.

## License

See the distribution files for license information.
