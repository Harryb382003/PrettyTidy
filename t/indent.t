use v5.40.0;
use common::sense;
use feature 'signatures';

use lib 'lib';
use Test::More;
use Mojo::PrettyTidy;

my $pt = Mojo::PrettyTidy->new( indent_width => 2 );

subtest 'attribute-level EP line is left alone' => sub {
  my $in = "<div>\n<a href=\"<%= \$url %>\">Link</a>\n</div>\n";

  my $expected = "<div>\n<a href=\"<%= \$url %>\">Link</a>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'attribute-level EP line is not reindented';
};

subtest 'doctype line is kept at current level' => sub {
  my $in = "<!DOCTYPE html>\n<div>\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<!DOCTYPE html>\n<div>\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'doctype line stays neutral and does not affect nesting';
};

subtest 'html comment line is kept at current level' => sub {
  my $in = "<div>\n<!-- note -->\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n  <!-- note -->\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'comment line is indented to current level';
};

subtest 'html comment near EP lines is left safe' => sub {
  my $in = "<div>\n<%= \$title %>\n<!-- note -->\n<p>\nHello\n</p>\n</div>\n";

  my $expected =
"<div>\n<%= \$title %>\n  <!-- note -->\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'comment line indents normally while EP line stays untouched';
};

subtest 'inline EP in html line is left alone' => sub {
  my $in = "<div>\n<div><%= \$name %></div>\n</div>\n";

  my $expected = "<div>\n<div><%= \$name %></div>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'inline EP line is not reindented';
};

subtest 'leading EP tag lines are left alone' => sub {
  my $in = "<%= \$title %>\n<div>\n<span>\nHi\n</span>\n</div>\n";

  my $expected = "<%= \$title %>\n<div>\n  <span>\n    Hi\n  </span>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'leading EP tag lines remain untouched';
};

subtest 'mixed EP block tag line is left alone' => sub {
  my $in = "<div>\n<% if (\$ok) { %>\n<p>Hello</p>\n<% } %>\n</div>\n";

  my $expected = "<div>\n<% if (\$ok) { %>\n<p>Hello</p>\n<% } %>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'mixed EP block lines are not reindented';
};

subtest 'multiline html comment block is indented consistently' => sub {
  my $in = "<div>\n<!--\ncomment\n-->\n<p>\nHello\n</p>\n</div>\n";

  my $expected =
      "<div>\n  <!--\n  comment\n  -->\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'multiline comment block is indented at the current level';
};

subtest 'multiline html comment near EP lines keeps EP safe' => sub {
  my $in = "<div>\n<%= \$title %>\n<!--\nnote\n-->\n<p>\nHello\n</p>\n</div>\n";

  my $expected =
"<div>\n<%= \$title %>\n  <!--\n  note\n  -->\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'multiline comment block indents normally while EP line stays untouched';
};

subtest 'percent directive lines are left structurally alone' => sub {
  my $in = "% if (\$ok) {\n<div>\n<p>Hello</p>\n</div>\n% }\n";

  my $expected = "% if (\$ok) {\n<div>\n<p>Hello</p>\n</div>\n% }\n";

  is $pt->tidy( $in ), $expected, 'percent directive lines remain untouched';
};

subtest 'plain text inside nested html is indented to current level' => sub {
  my $in = "<div>\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'plain text line is indented inside nested tags';
};

subtest 'plain text near EP lines is indented but EP lines are left alone' =>
    sub {
  my $in = "<div>\n<%= \$title %>\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n<%= \$title %>\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'plain text is indented and EP line is preserved';
    };

subtest 'single-line mixed tag/content lines are left alone' => sub {
  my $in = "<div>\n<p>Hello</p>\n</div>\n";

  my $expected = "<div>\n<p>Hello</p>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'mixed content line is left alone';
};

subtest 'void elements do not increase indentation' => sub {
  my $in = "<div>\n<img src=\"x.png\">\n<p>\nHello\n</p>\n</div>\n";

  my $expected =
      "<div>\n  <img src=\"x.png\">\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'void tags do not shift indentation depth';
};

done_testing;
