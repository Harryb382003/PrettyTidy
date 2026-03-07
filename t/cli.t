use v5.40.0;
use common::sense;
use feature 'signatures';

use lib 'lib';
use lib 't/lib';

use Test::More;
use File::Temp qw(tempfile);
use File::Spec;
use Mojo::PrettyTidy;
use Test::CLI::Capture qw(run_cmd);

my $script = File::Spec->catfile(qw(script mojo-prettytidy));

ok -e $script, 'CLI script exists';
ok -x $script, 'CLI script is executable';

sub slurp ($path) {
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

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, $path ],
  );

  is $r->{exit},   0,               'exit status is 0';
  is $r->{stdout}, "alpha\nbeta\n", 'stdout contains tidied content';
  is $r->{stderr}, '',              'stderr is empty';
  is slurp($path), "alpha  \nbeta\t \n", 'input file was not modified';
};

subtest '--backup without --write is rejected' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, '--backup', $path ],
  );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--backup requires --write/, 'stderr explains invalid usage';
};

subtest '--check returns 0 for tidy input' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha\nbeta\n";
  close $fh;

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, '--check', $path ],
  );

  is $r->{exit},   0,  '--check exits 0 when no changes are needed';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';
};

subtest '--check returns 1 for untidy input' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, '--check', $path ],
  );

  is $r->{exit},   1,  '--check exits 1 when changes would be made';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';
};

subtest '--diff returns 0 when no changes are needed' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha\nbeta\n";
  close $fh;

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, '--diff', $path ],
  );

  is $r->{exit},   0,  '--diff exits 0 when no changes are needed';
  is $r->{stdout}, '', 'stdout is empty when no diff is needed';
  is $r->{stderr}, '', 'stderr is empty';
};


subtest '--diff returns 1 and prints diff when changes are needed' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, '--diff', $path ],
  );

  is $r->{exit}, 1, '--diff exits 1 when changes are found';
  like $r->{stdout}, qr/^\-\-\- \Q$path\E \(original\)$/m, 'diff includes original header';
  like $r->{stdout}, qr/^\+\+\+ \Q$path\E \(tidied\)$/m,   'diff includes tidied header';
  like $r->{stdout}, qr/^\@\@ /m,                          'diff includes hunk header';
  like $r->{stdout}, qr/^-alpha  $/m,                     'diff shows original line';
  like $r->{stdout}, qr/^\+alpha$/m,                      'diff shows tidied line';
  is $r->{stderr}, '', 'stderr is empty';
};

subtest '--diff with --write is rejected' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \n";
  close $fh;

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, '--diff', '--write', $path ],
  );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--diff cannot be combined with --write/, 'stderr explains invalid usage';
};

subtest '--stdin reads stdin and writes stdout' => sub {
  my $r = run_cmd(
    argv  => [ $^X, '-Ilib', $script, '--stdin' ],
    stdin => "alpha  \nbeta\t \n",
  );

  is $r->{exit},   0,               '--stdin exits 0';
  is $r->{stdout}, "alpha\nbeta\n", '--stdin writes tidied content';
  is $r->{stderr}, '',              'stderr is empty';
};

subtest '--write rewrites the file in place' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, '--write', $path ],
  );

  is $r->{exit},   0,  '--write exits 0';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';
  is slurp($path), "alpha\nbeta\n", 'file was rewritten in place';
};

subtest '--write --backup creates backup and rewrites file' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $backup_path = $path . '.bak';

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, '--write', '--backup', $path ],
  );

  is $r->{exit},   0,  '--write --backup exits 0';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';
  ok -e $backup_path, 'backup file exists';
  is slurp($backup_path), "alpha  \nbeta\t \n", 'backup contains original content';
  is slurp($path),       "alpha\nbeta\n",       'original file was rewritten';
};

subtest '--write --backup-ext uses custom suffix' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $backup_path = $path . '.orig';

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, '--write', '--backup', '--backup-ext=.orig', $path ],
  );

  is $r->{exit},   0,  'custom backup suffix exits 0';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';
  ok -e $backup_path, 'custom backup file exists';
  is slurp($backup_path), "alpha  \nbeta\t \n", 'custom backup contains original content';
  is slurp($path),       "alpha\nbeta\n",       'original file was rewritten';
};

subtest '--version prints version and exits 0' => sub {
  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, '--version' ],
  );

  is $r->{exit}, 0, '--version exits 0';
  like(
    $r->{stdout},
    qr/^mojo-prettytidy \Q$Mojo::PrettyTidy::VERSION\E\n\z/,
    '--version prints script version',
  );
  is $r->{stderr}, '', 'stderr is empty';
};

done_testing;
