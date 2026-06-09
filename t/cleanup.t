use v5.40.0;
use common::sense;
use feature 'signatures';

use lib 'lib';
use lib 't/lib';

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path         qw(make_path);
use Test::CLI::Capture qw(run_cmd);

my $root   = File::Spec->rel2abs( File::Spec->curdir );
my $lib    = File::Spec->catdir( $root, 'lib' );
my $tlib   = File::Spec->catdir( $root, 't', 'lib' );
my $script = File::Spec->catfile( $root, qw(bin mojo-prettytidy) );

ok -e $script, 'CLI script exists';
ok -x $script, 'CLI script is executable';

sub spurt ( $path, $content ) {
  open my $fh, '>', $path or die "Cannot open '$path' for writing: $!";
  print {$fh} $content;
  close $fh;
}

sub slurp ( $path ) {
  open my $fh, '<', $path or die "Cannot open '$path' for reading: $!";
  local $/;
  my $content = <$fh>;
  close $fh;
  return $content;
}

sub cli_argv ( @args ) {
  return [ $^X, '-I' . $lib, '-I' . $tlib, $script, @args ];
}

sub run_isolated ( %args ) {
  my $tmpdir = $args{tmpdir};

  my %env = (
              HOME => $tmpdir,
              PATH => $ENV{PATH} // '', );

  return
      run_cmd(
               argv => $args{argv},
               cwd  => $tmpdir,
               env  => \%env, );
}

sub stale_artifact_paths ( $tmpdir ) {
  return (
           File::Spec->catfile( $tmpdir, qw(tmp pt.raw-perltidy.out) ),
           File::Spec->catfile( $tmpdir, qw(tmp perltidy pt-region-001.pl) ),
           File::Spec->catfile(
                                $tmpdir, qw(tmp perltidy pt-region-001.pl.LOG)
           ),
           File::Spec->catfile(
                                $tmpdir, qw(tmp perltidy pt-region-001.pl.ERR)
           ), );
}

sub create_stale_artifacts ( $tmpdir ) {
  my $tmp      = File::Spec->catdir( $tmpdir, 'tmp' );
  my $perltidy = File::Spec->catdir( $tmpdir, qw(tmp perltidy) );

  make_path( $perltidy );

  for my $path ( stale_artifact_paths( $tmpdir ) ) {
    spurt( $path, "stale\n" );
  }

  return;
}

sub all_stale_artifacts_exist ( $tmpdir ) {
  for my $path ( stale_artifact_paths( $tmpdir ) ) {
    return 0 if !-e $path;
  }

  return 1;
}

sub no_stale_artifacts_exist ( $tmpdir ) {
  for my $path ( stale_artifact_paths( $tmpdir ) ) {
    return 0 if -e $path;
  }

  return 1;
}

subtest
    'cleanup is enabled by default and removes stale PrettyTidy artifacts' =>
    sub {
  my $tmpdir = tempdir( CLEANUP => 1 );
  my $input  = File::Spec->catfile( $tmpdir, 'one.html.ep' );

  spurt( $input, "<div><span>alpha</span></div>\n" );
  create_stale_artifacts( $tmpdir );

  ok all_stale_artifacts_exist( $tmpdir ), 'stale artifacts exist before run';

  my $r = run_isolated( tmpdir => $tmpdir, argv => cli_argv( $input ) );

  is $r->{exit}, 0, 'formatter exits 0';

  for my $path ( stale_artifact_paths( $tmpdir ) ) {
    ok !-e $path, "removed stale artifact $path"
        or diag "still exists: $path";
  }
    };

subtest '--no-cleanup preserves stale PrettyTidy artifacts' => sub {
  my $tmpdir = tempdir( CLEANUP => 1 );
  my $input  = File::Spec->catfile( $tmpdir, 'one.html.ep' );

  spurt( $input, "<div><span>alpha</span></div>\n" );
  create_stale_artifacts( $tmpdir );

  ok all_stale_artifacts_exist( $tmpdir ), 'stale artifacts exist before run';

  my $r = run_isolated( tmpdir => $tmpdir,
                        argv   => cli_argv( '--no-cleanup', $input ), );

  is $r->{exit}, 0, 'formatter exits 0';
  ok all_stale_artifacts_exist( $tmpdir ),
      '--no-cleanup preserves stale PrettyTidy artifacts';
};

subtest '-V reports cleanup option source' => sub {
  my $tmpdir = tempdir( CLEANUP => 1 );
  my $input  = File::Spec->catfile( $tmpdir, 'one.html.ep' );

  spurt( $input, "<div>alpha</div>\n" );

  my $default = run_isolated( tmpdir => $tmpdir,
                              argv   => cli_argv( '-VV', $input ), );

  my $default_text =
      ( $default->{stdout} // '' ) . ( $default->{stderr} // '' );

  is $default->{exit}, 0, '-VV exits 0';
  like $default_text, qr/cleanup\s+=>\s+1\s+\[default\]/, 'cleanup defaults on';

  my $disabled = run_isolated( tmpdir => $tmpdir,
                               argv => cli_argv( '-V', '--no-cleanup', $input ),
  );

  my $disabled_text =
      ( $disabled->{stdout} // '' ) . ( $disabled->{stderr} // '' );

  is $disabled->{exit}, 0, '-V with --no-cleanup exits 0';
  like $disabled_text, qr/cleanup\s+=>\s+0\s+\[cli\]/,
      '--no-cleanup is visible in show-options';
};

done_testing;
