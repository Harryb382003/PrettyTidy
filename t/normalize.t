use v5.40;
use common::sense;

use Test::More;
use Mojo::PrettyTidy;

my $pt = Mojo::PrettyTidy->new;

subtest 'trailing whitespace is removed' => sub {
  my $in  = "alpha  \nbeta\t \n";
  my $out = "alpha\nbeta\n";

  is $pt->tidy( $in ), $out, 'removed trailing horizontal whitespace';
};

subtest 'CRLF is normalized to LF' => sub {
  my $in  = "alpha\r\nbeta\r\n";
  my $out = "alpha\nbeta\n";

  is $pt->tidy( $in ), $out, 'normalized CRLF';
};

subtest 'CR is normalized to LF' => sub {
  my $in  = "alpha\rbeta\r";
  my $out = "alpha\nbeta\n";

  is $pt->tidy( $in ), $out, 'normalized CR';
};

subtest 'final newline is ensured' => sub {
  is $pt->tidy( "alpha" ), "alpha\n", 'added final newline';
};

subtest 'multiple trailing newlines collapse to one' => sub {
  is $pt->tidy( "alpha\n\n\n" ), "alpha\n", 'collapsed EOF newlines';
};

subtest 'already tidy input is unchanged' => sub {
  my $in = "alpha\nbeta\n";

  is $pt->tidy( $in ), $in, 'tidy output matches input';
  ok $pt->check( $in ), 'check reports no change needed';
};

subtest 'check reports when changes would be made' => sub {
  ok !$pt->check( "alpha  \n" ), 'check reports dirty input';
};

done_testing;
