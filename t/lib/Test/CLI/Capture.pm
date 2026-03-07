package Test::CLI::Capture;

use v5.40.0;
use common::sense;

use Exporter qw(import);
our @EXPORT_OK = qw(run_cmd);

use IO::Handle;
use IO::Select;

sub run_cmd {
  my ( %args ) = @_;

  my $argv  = $args{argv} // die "run_cmd requires 'argv'";
  my $stdin = defined $args{stdin} ? $args{stdin} : '';

  ref $argv eq 'ARRAY' or die "'argv' must be an array reference";
  @$argv               or die "'argv' must not be empty";

  pipe( my $child_out_r, my $child_out_w ) or die "pipe(stdout) failed: $!";
  pipe( my $child_err_r, my $child_err_w ) or die "pipe(stderr) failed: $!";
  pipe( my $child_in_r,  my $child_in_w )  or die "pipe(stdin) failed: $!";

  $_->autoflush( 1 )
      for grep {defined} ( $child_out_w, $child_err_w, $child_in_w );

  my $pid = fork();
  defined $pid or die "fork failed: $!";

  if ( $pid == 0 ) {
    close $child_out_r or die "close child_out_r failed: $!";
    close $child_err_r or die "close child_err_r failed: $!";
    close $child_in_w  or die "close child_in_w failed: $!";

    open STDOUT, '>&', fileno( $child_out_w ) or die "dup STDOUT failed: $!";
    open STDERR, '>&', fileno( $child_err_w ) or die "dup STDERR failed: $!";
    open STDIN,  '<&', fileno( $child_in_r )  or die "dup STDIN failed: $!";

    close $child_out_w or die "close child_out_w failed: $!";
    close $child_err_w or die "close child_err_w failed: $!";
    close $child_in_r  or die "close child_in_r failed: $!";

    exec @$argv or die "exec(@$argv) failed: $!";
  }

  close $child_out_w or die "close parent child_out_w failed: $!";
  close $child_err_w or die "close parent child_err_w failed: $!";
  close $child_in_r  or die "close parent child_in_r failed: $!";

  my $stdin_bytes = defined $stdin ? $stdin : '';
  my $stdin_len   = length $stdin_bytes;
  my $stdin_off   = 0;

  my $stdout = '';
  my $stderr = '';

  my $selector = IO::Select->new();

  $selector->add( $child_out_r );
  $selector->add( $child_err_r );
  $selector->add( $child_in_w ) if $stdin_len > 0;

  my %kind_for = (
                   fileno( $child_out_r ) => 'stdout',
                   fileno( $child_err_r ) => 'stderr',
                   fileno( $child_in_w )  => 'stdin', );

  while ( $selector->count ) {
    for my $fh ( $selector->can_write( 0.1 ) ) {
      my $fileno = fileno( $fh );
      my $kind   = $kind_for{$fileno} // next;
      next unless $kind eq 'stdin';

      if ( $stdin_off >= $stdin_len ) {
        $selector->remove( $fh );
        close $fh or die "close stdin pipe failed: $!";
        next;
      }

      my $written =
          syswrite( $fh, $stdin_bytes, $stdin_len - $stdin_off, $stdin_off );

      if ( !defined $written ) {
        next if $!{EINTR} || $!{EAGAIN};
        die "syswrite(stdin) failed: $!";
      }

      $stdin_off += $written;

      if ( $stdin_off >= $stdin_len ) {
        $selector->remove( $fh );
        close $fh or die "close stdin pipe failed: $!";
      }
    }

    for my $fh ( $selector->can_read( 0.1 ) ) {
      my $fileno = fileno( $fh );
      my $kind   = $kind_for{$fileno} // next;
      next if $kind eq 'stdin';

      my $buf  = '';
      my $read = sysread( $fh, $buf, 8192 );

      if ( !defined $read ) {
        next if $!{EINTR} || $!{EAGAIN};
        die "sysread($kind) failed: $!";
      }

      if ( $read == 0 ) {
        $selector->remove( $fh );
        close $fh or die "close $kind pipe failed: $!";
        next;
      }

      if ( $kind eq 'stdout' ) {
        $stdout .= $buf;
      }
      elsif ( $kind eq 'stderr' ) {
        $stderr .= $buf;
      }
    }

    if ( $stdin_len == 0 && defined fileno( $child_in_w ) ) {
      $selector->remove( $child_in_w );
      close $child_in_w;
    }
  }

  waitpid( $pid, 0 );
  my $exit = $? >> 8;

  return {
          stdout => $stdout,
          stderr => $stderr,
          exit   => $exit,};
}

1;

__END__

=pod

=head1 NAME

Test::CLI::Capture - Core-only subprocess capture helper for tests

=head1 SYNOPSIS

    use Test::CLI::Capture qw(run_cmd);

    my $r = run_cmd(
      argv  => [ $^X, '-Ilib', 'script/mojo-prettytidy', '--stdin' ],
      stdin => "alpha  \n",
    );

=head1 DESCRIPTION

This module provides a small core-only helper for running a subprocess
in tests while capturing standard input, standard output, standard
error, and exit status.

It avoids shell quoting issues by executing an argument vector
directly, and avoids the common deadlock pattern of draining stdout
and stderr serially by multiplexing pipe I/O with C<IO::Select>.

=head1 FUNCTIONS

=head2 run_cmd

    my $r = run_cmd(
      argv  => \@argv,
      stdin => $input,
    );

Returns a hash reference containing:

=over 4

=item * C<stdout>

=item * C<stderr>

=item * C<exit>

=back

=head1 LICENSE

Same terms as Perl itself.

=cut
