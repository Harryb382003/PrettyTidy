use v5.40.0;
use common::sense;
use feature 'signatures';

use lib 'lib';
use Test::More;
use Mojo::PrettyTidy;

my $pt = Mojo::PrettyTidy->new( indent_width => 2 );

subtest 'pure tag lines are indented' => sub {
  my $in = "<div>\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n  <p>\nHello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'only obvious tag-only lines are indented';
};

subtest 'single-line mixed tag/content lines are left alone' => sub {
  my $in = "<div>\n<p>Hello</p>\n</div>\n";

  my $expected = "<div>\n<p>Hello</p>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'mixed content line is left alone';
};

subtest 'percent directive lines are left structurally alone' => sub {
  my $in = "% if (\$ok) {\n<div>\n<p>Hello</p>\n</div>\n% }\n";

  my $expected = "% if (\$ok) {\n<div>\n<p>Hello</p>\n</div>\n% }\n";

  is $pt->tidy( $in ), $expected, 'percent directive lines remain untouched';
};

subtest 'leading EP tag lines are left alone' => sub {
  my $in = "<%= \$title %>\n<div>\n<span>\nHi\n</span>\n</div>\n";

  my $expected = "<%= \$title %>\n<div>\n  <span>\nHi\n  </span>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'leading EP tag lines remain untouched';
};

subtest 'void elements do not increase indentation' => sub {
  my $in = "<div>\n<img src=\"x.png\">\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n  <img src=\"x.png\">\n  <p>\nHello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'void tags do not shift indentation depth';
};

done_testing;
