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

my $script = File::Spec->catfile( qw(script mojo-prettytidy) );

ok -e $script, 'CLI script exists';
ok -x $script, 'CLI script is executable';

sub slurp ( $path ) {
  open my $fh, '<', $path or die "Cannot open '$path' for reading: $!";
  local $/;
  my $content = <$fh>;
  close $fh;
  return $content;
}

sub spurt ( $path, $content ) {
  open my $fh, '>', $path or die "Cannot open '$path' for writing: $!";
  print {$fh} $content;
  close $fh;
}

subtest 'default mode writes tidied content to stdout' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, $path ], );

  is $r->{exit},     0,                    'exit status is 0';
  is $r->{stdout},   "alpha\nbeta\n",      'stdout contains tidied content';
  is $r->{stderr},   '',                   'stderr is empty';
  is slurp( $path ), "alpha  \nbeta\t \n", 'input file was not modified';
};

subtest '--backup without --write is rejected' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, '--backup', $path ], );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--backup requires --write/,
      'stderr explains invalid usage';
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

subtest '--diff returns 0 when no changes are needed' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha\nbeta\n";
  close $fh;

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, '--diff', $path ], );

  is $r->{exit},   0,  '--diff exits 0 when no changes are needed';
  is $r->{stdout}, '', 'stdout is empty when no diff is needed';
  is $r->{stderr}, '', 'stderr is empty';
};

subtest '--diff returns 1 and prints diff when changes are needed' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, '--diff', $path ], );

  is $r->{exit}, 1, '--diff exits 1 when changes are found';
  like $r->{stdout}, qr/^\-\-\- \Q$path\E \(original\)$/m,
      'diff includes original header';
  like $r->{stdout}, qr/^\+\+\+ \Q$path\E \(tidied\)$/m,
      'diff includes tidied header';
  like $r->{stdout}, qr/^\@\@ /m,     'diff includes hunk header';
  like $r->{stdout}, qr/^-alpha  $/m, 'diff shows original line';
  like $r->{stdout}, qr/^\+alpha$/m,  'diff shows tidied line';
  is $r->{stderr}, '', 'stderr is empty';
};

subtest '--diff with --write is rejected' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \n";
  close $fh;

  my $r =
      run_cmd( argv => [ $^X, '-Ilib', $script, '--diff', '--write', $path ], );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--diff cannot be combined with --write/,
      'stderr explains invalid usage';
};

subtest '--output writes tidied content to a separate file' => sub {
  my ( $in_fh,  $in_path )  = tempfile();
  my ( $out_fh, $out_path ) = tempfile();
  close $out_fh;

  print {$in_fh} "alpha  \nbeta\t \n";
  close $in_fh;

  my $r = run_cmd(
          argv => [ $^X, '-Ilib', $script, '--output', $out_path, $in_path ], );

  is $r->{exit},         0,                    '--output exits 0';
  is $r->{stdout},       '',                   'stdout is empty';
  is $r->{stderr},       '',                   'stderr is empty';
  is slurp( $in_path ),  "alpha  \nbeta\t \n", 'input file was not modified';
  is slurp( $out_path ), "alpha\nbeta\n", 'output file received tidied content';
};

subtest '--output with --check is rejected' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha\n";
  close $fh;

  my $r = run_cmd(
     argv => [ $^X, '-Ilib', $script, '--check', '--output', 'out.txt', $path ],
  );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--output cannot be combined with --check/,
      'stderr explains invalid usage';
};

subtest '--output with --diff is rejected' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha\n";
  close $fh;

  my $r = run_cmd(
      argv => [ $^X, '-Ilib', $script, '--diff', '--output', 'out.txt', $path ],
  );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--output cannot be combined with --diff/,
      'stderr explains invalid usage';
};

subtest '--output with --write is rejected' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \n";
  close $fh;

  my $r = run_cmd(
     argv => [ $^X, '-Ilib', $script, '--write', '--output', 'out.txt', $path ],
  );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--output cannot be combined with --write/,
      'stderr explains invalid usage';
};

subtest '--stdin with --output writes tidied content to a file' => sub {
  my ( $fh, $out_path ) = tempfile();
  close $fh;

  my $r = run_cmd(
           argv  => [ $^X, '-Ilib', $script, '--stdin', '--output', $out_path ],
           stdin => "alpha  \nbeta\t \n", );

  is $r->{exit},   0,  '--stdin with --output exits 0';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';
  is slurp( $out_path ), "alpha\nbeta\n",
      'output file received tidied stdin content';
};

subtest '--write rewrites the file in place' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, '--write', $path ], );

  is $r->{exit},     0,               '--write exits 0';
  is $r->{stdout},   '',              'stdout is empty';
  is $r->{stderr},   '',              'stderr is empty';
  is slurp( $path ), "alpha\nbeta\n", 'file was rewritten in place';
};

subtest '--write --backup creates backup and rewrites file' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $backup_path = $path . '.bak';

  my $r =
      run_cmd( argv => [ $^X, '-Ilib', $script, '--write', '--backup', $path ],
      );

  is $r->{exit},   0,  '--write --backup exits 0';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';
  ok -e $backup_path, 'backup file exists';
  is slurp( $backup_path ), "alpha  \nbeta\t \n",
      'backup contains original content';
  is slurp( $path ), "alpha\nbeta\n", 'original file was rewritten';
};

subtest '--write --backup-ext uses custom suffix' => sub {
  my ( $fh, $path ) = tempfile();
  print {$fh} "alpha  \nbeta\t \n";
  close $fh;

  my $backup_path = $path . '.orig';

  my $r = run_cmd(
                   argv => [
                             $^X,        '-Ilib',
                             $script,    '--write',
                             '--backup', '--backup-ext=.orig',
                             $path
                   ], );

  is $r->{exit},   0,  'custom backup suffix exits 0';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';
  ok -e $backup_path, 'custom backup file exists';
  is slurp( $backup_path ), "alpha  \nbeta\t \n",
      'custom backup contains original content';
  is slurp( $path ), "alpha\nbeta\n", 'original file was rewritten';
};

subtest '--version prints version and exits 0' => sub {
  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, '--version' ], );

  is $r->{exit}, 0, '--version exits 0';
  like( $r->{stdout},
        qr/^mojo-prettytidy \Q$Mojo::PrettyTidy::VERSION\E\n\z/,
        '--version prints script version', );
  is $r->{stderr}, '', 'stderr is empty';
};

############

subtest 'multiple input files with --prefix write sibling outputs' => sub {
  my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );

  my $in1 = File::Spec->catfile( $tmpdir, 'one.html.ep' );
  my $in2 = File::Spec->catfile( $tmpdir, 'two.html.ep' );

  spurt( $in1, "alpha  \n" );
  spurt( $in2, "beta\t \n" );

  my $out1 = File::Spec->catfile( $tmpdir, 'pt.one.html.ep' );
  my $out2 = File::Spec->catfile( $tmpdir, 'pt.two.html.ep' );

  my $r =
      run_cmd( argv => [ $^X, '-Ilib', $script, $in1, $in2, '--prefix', 'pt.' ],
      );

  is $r->{exit},   0,  'multi-file --prefix exits 0';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';

  ok -e $out1, 'prefixed output for first file exists';
  ok -e $out2, 'prefixed output for second file exists';

  is slurp( $out1 ), "alpha\n", 'first prefixed output was tidied';
  is slurp( $out2 ), "beta\n",  'second prefixed output was tidied';

  is slurp( $in1 ), "alpha  \n", 'first input was not modified';
  is slurp( $in2 ), "beta\t \n", 'second input was not modified';
};

subtest 'multiple input files with --prefix and --outdir write to output dir' =>
    sub {
  my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );
  my $outdir = File::Spec->catdir( $tmpdir, 'parsed' );
  mkdir $outdir or die "Cannot mkdir '$outdir': $!";

  my $in1 = File::Spec->catfile( $tmpdir, 'one.html.ep' );
  my $in2 = File::Spec->catfile( $tmpdir, 'two.html.ep' );

  spurt( $in1, "alpha  \n" );
  spurt( $in2, "beta\t \n" );

  my $out1 = File::Spec->catfile( $outdir, 'pt.one.html.ep' );
  my $out2 = File::Spec->catfile( $outdir, 'pt.two.html.ep' );

  my $r = run_cmd(
                   argv => [
                             $^X,   '-Ilib',    $script, $in1, $in2, '--prefix',
                             'pt.', '--outdir', $outdir
                   ], );

  is $r->{exit},   0,  'multi-file --prefix --outdir exits 0';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';

  ok -e $out1, 'first output file exists in outdir';
  ok -e $out2, 'second output file exists in outdir';

  is slurp( $out1 ), "alpha\n", 'first outdir file was tidied';
  is slurp( $out2 ), "beta\n",  'second outdir file was tidied';
    };

subtest
    'directory input with --prefix and --outdir writes matching html.ep files'
    => sub {
  my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );
  my $indir  = File::Spec->catdir( $tmpdir, 'templates' );
  my $outdir = File::Spec->catdir( $tmpdir, 'parsed' );

  mkdir $indir  or die "Cannot mkdir '$indir': $!";
  mkdir $outdir or die "Cannot mkdir '$outdir': $!";

  my $ep1 = File::Spec->catfile( $indir, 'one.html.ep' );
  my $ep2 = File::Spec->catfile( $indir, 'two.html.ep' );
  my $txt = File::Spec->catfile( $indir, 'ignore.txt' );
  my $oth = File::Spec->catfile( $indir, 'three.js.ep' );

  spurt( $ep1, "alpha  \n" );
  spurt( $ep2, "beta\t \n" );
  spurt( $txt, "leave me alone\n" );
  spurt( $oth, "also ignored\n" );

  my $out1 = File::Spec->catfile( $outdir, 'pt.one.html.ep' );
  my $out2 = File::Spec->catfile( $outdir, 'pt.two.html.ep' );
  my $out3 = File::Spec->catfile( $outdir, 'pt.ignore.txt' );
  my $out4 = File::Spec->catfile( $outdir, 'pt.three.js.ep' );

  my $r = run_cmd(
                   argv => [
                             $^X,        '-Ilib', $script,    $indir,
                             '--prefix', 'pt.',   '--outdir', $outdir
                   ], );

  is $r->{exit},   0,  'directory input exits 0';
  is $r->{stdout}, '', 'stdout is empty';
  is $r->{stderr}, '', 'stderr is empty';

  ok -e $out1,  'first html.ep output exists';
  ok -e $out2,  'second html.ep output exists';
  ok !-e $out3, 'non-template file was ignored';
  ok !-e $out4, 'non-html.ep ep-like file was ignored';

  is slurp( $out1 ), "alpha\n", 'first directory result was tidied';
  is slurp( $out2 ), "beta\n",  'second directory result was tidied';
    };

subtest 'multiple inputs without destination mode are rejected' => sub {
  my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );

  my $in1 = File::Spec->catfile( $tmpdir, 'one.html.ep' );
  my $in2 = File::Spec->catfile( $tmpdir, 'two.html.ep' );

  spurt( $in1, "alpha\n" );
  spurt( $in2, "beta\n" );

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, $in1, $in2 ], );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/multiple input/i,
      'stderr explains multiple inputs need an output mode';
};

subtest '--write with --prefix is rejected' => sub {
  my ( $fh, $path ) = tempfile( SUFFIX => '.html.ep' );
  print {$fh} "alpha  \n";
  close $fh;

  my $r = run_cmd(
      argv => [ $^X, '-Ilib', $script, $path, '--write', '--prefix', 'pt.' ], );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--write cannot be combined with --prefix/,
      'stderr explains invalid usage';
};

subtest '--write with --outdir is rejected' => sub {
  my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );
  my $outdir = File::Spec->catdir( $tmpdir, 'parsed' );
  mkdir $outdir or die "Cannot mkdir '$outdir': $!";

  my ( $fh, $path ) = tempfile( DIR => $tmpdir, SUFFIX => '.html.ep' );
  print {$fh} "alpha  \n";
  close $fh;

  my $r = run_cmd(
    argv => [ $^X, '-Ilib', $script, $path, '--write', '--outdir', $outdir ], );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--write cannot be combined with --outdir/,
      'stderr explains invalid usage';
};

subtest '--output with multiple inputs is rejected' => sub {
  my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );

  my $in1 = File::Spec->catfile( $tmpdir, 'one.html.ep' );
  my $in2 = File::Spec->catfile( $tmpdir, 'two.html.ep' );
  my $out = File::Spec->catfile( $tmpdir, 'out.html.ep' );

  spurt( $in1, "alpha\n" );
  spurt( $in2, "beta\n" );

  my $r =
      run_cmd( argv => [ $^X, '-Ilib', $script, $in1, $in2, '--output', $out ],
      );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--output.*multiple input|multiple input.*--output/i,
      'stderr explains invalid usage';
};

subtest '--check with directory input is rejected' => sub {
  my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );
  my $indir  = File::Spec->catdir( $tmpdir, 'templates' );
  mkdir $indir or die "Cannot mkdir '$indir': $!";

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, '--check', $indir ], );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--check.*single|directory.*not supported/i,
      'stderr explains invalid usage';
};

subtest '--diff with directory input is rejected' => sub {
  my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );
  my $indir  = File::Spec->catdir( $tmpdir, 'templates' );
  mkdir $indir or die "Cannot mkdir '$indir': $!";

  my $r = run_cmd( argv => [ $^X, '-Ilib', $script, '--diff', $indir ], );

  isnt $r->{exit}, 0, 'exit is non-zero';
  like $r->{stderr}, qr/--diff.*single|directory.*not supported/i,
      'stderr explains invalid usage';
};

done_testing;
