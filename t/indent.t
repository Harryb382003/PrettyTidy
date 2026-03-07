use v5.40.0;
use common::sense;
use feature 'signatures';

use lib 'lib';
use Test::More;
use Mojo::PrettyTidy;

my $pt = Mojo::PrettyTidy->new( indent_width => 2 );

subtest 'plain text inside nested html is indented to current level' => sub {
  my $in = "<div>\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy($in), $expected,
  'plain text line is indented inside nested tags';
};

subtest 'plain text near EP lines is indented but EP lines are left alone' => sub {
  my $in = "<div>\n<%= \$title %>\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n<%= \$title %>\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy($in), $expected,
  'plain text is indented and EP line is preserved';
};

subtest 'leading EP tag lines are left alone' => sub {
  my $in = "<%= \$title %>\n<div>\n<span>\nHi\n</span>\n</div>\n";

  my $expected = "<%= \$title %>\n<div>\n  <span>\n    Hi\n  </span>\n</div>\n";

  is $pt->tidy($in), $expected, 'leading EP tag lines remain untouched';
};

subtest 'percent directive lines are left structurally alone' => sub {
  my $in = "% if (\$ok) {\n<div>\n<p>Hello</p>\n</div>\n% }\n";

  my $expected = "% if (\$ok) {\n<div>\n<p>Hello</p>\n</div>\n% }\n";

  is $pt->tidy($in), $expected, 'percent directive lines remain untouched';
};

subtest 'mixed EP block tag line is left alone' => sub {
  my $in = "<div>\n<% if (\$ok) { %>\n<p>Hello</p>\n<% } %>\n</div>\n";

  my $expected = "<div>\n<% if (\$ok) { %>\n<p>Hello</p>\n<% } %>\n</div>\n";

  is $pt->tidy($in), $expected, 'mixed EP block lines are not reindented';
};

subtest 'inline EP in html line is left alone' => sub {
  my $in = "<div>\n<div><%= \$name %></div>\n</div>\n";

  my $expected = "<div>\n<div><%= \$name %></div>\n</div>\n";

  is $pt->tidy($in), $expected, 'inline EP line is not reindented';
};

subtest 'attribute-level EP line is left alone' => sub {
  my $in = "<div>\n<a href=\"<%= \$url %>\">Link</a>\n</div>\n";

  my $expected = "<div>\n<a href=\"<%= \$url %>\">Link</a>\n</div>\n";

  is $pt->tidy($in), $expected, 'attribute-level EP line is not reindented';
};

subtest 'single-line mixed tag/content lines are left alone' => sub {
  my $in = "<div>\n<p>Hello</p>\n</div>\n";

  my $expected = "<div>\n<p>Hello</p>\n</div>\n";

  is $pt->tidy($in), $expected, 'mixed content line is left alone';
};

subtest 'void elements do not increase indentation' => sub {
  my $in = "<div>\n<img src=\"x.png\">\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n  <img src=\"x.png\">\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy($in), $expected, 'void tags do not shift indentation depth';
};

done_testing;
