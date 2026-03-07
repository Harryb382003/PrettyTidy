use v5.40.0;
use common::sense;
use feature 'signatures';

use lib 'lib';

use Test::More;
use Mojo::PrettyTidy::Diff qw(unified_diff);

subtest 'no diff for identical input' => sub {
  my $diff = unified_diff( old => "alpha\nbeta\n",
                           new => "alpha\nbeta\n", );

  is $diff, '', 'identical input returns empty diff';
};

subtest 'diff for changed input' => sub {
  my $diff = unified_diff(
                           old       => "alpha  \nbeta\t \n",
                           new       => "alpha\nbeta\n",
                           old_label => 'old.txt',
                           new_label => 'new.txt', );

  like $diff, qr/^--- old\.txt$/m,    'has old header';
  like $diff, qr/^\+\+\+ new\.txt$/m, 'has new header';
  like $diff, qr/^\@\@ /m,            'has hunk header';
  like $diff, qr/^-alpha  $/m,        'shows removed line';
  like $diff, qr/^\+alpha$/m,         'shows added line';
};

done_testing;
