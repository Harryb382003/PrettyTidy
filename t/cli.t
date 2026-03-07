use v5.40.0;
use common::sense;

use lib 't/lib';

use Test::More;
use File::Temp qw(tempfile);
use File::Spec;
use Test::CLI::Capture qw(run_cmd);

my $script = File::Spec->catfile( qw(script mojo-prettytidy) );

ok -e $script, 'CLI script exists';
ok -x $script, 'CLI script is executable';

sub slurp {
  my ( $path ) = @_;

  open my $fh, '<', $path or die "Cannot open '$path' for reading: $!";
  local $/;
  my $content = <$fh>;
  close $fh;

  return $content;
}

subtest 'default mode writes tidied content to stdout' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, $path ], );

  is $r->{exit},   0,               'exit status is 0';
  is $r->{stdout}, "alpha\nbeta\n", 'stdout contains tidied content';
  is $r->{stderr}, '',              'stderr is empty';

  is slurp( $path ), "alpha  \nbeta\t \n", 'input file was not modified';
};

subtest '--check returns 0 for tidy input' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha\nbeta\n";
  close $fh;

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, '--check', $path ], );

  is $r->{exit},   0,  '--check exits 0 when no changes are needed';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';
};

subtest '--check returns 1 for untidy input' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, '--check', $path ], );

  is $r->{exit},   1,  '--check exits 1 when changes would be made';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';
};

subtest '--write rewrites the file in place' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, '--write', $path ], );

  is $r->{exit},   0,  '--write exits 0';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';

  is slurp( $path ), "alpha\nbeta\n", 'file was rewritten in place';
};

subtest '--stdin reads stdin and writes stdout' => sub {
  my $r = run_cmd( argv  => [ $^X, '-Ilib', $script, '--stdin' ],
                   stdin => "alpha  \nbeta\t \n", );

  is $r->{exit},   0,               '--stdin exits 0';
  is $r->{stdout}, "alpha\nbeta\n", '--stdin writes tidied content';
  is $r->{stderr}, '',              'stderr is empty';
};

done_testing;
