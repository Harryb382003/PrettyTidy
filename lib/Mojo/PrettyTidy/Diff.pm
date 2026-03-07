package Mojo::PrettyTidy::Diff;

use v5.40.0;
use common::sense;
use feature 'signatures';

use Exporter qw(import);
our @EXPORT_OK = qw(unified_diff);

sub unified_diff ( %args ) {
  my $old       = defined $args{old}       ? $args{old}       : '';
  my $new       = defined $args{new}       ? $args{new}       : '';
  my $old_label = defined $args{old_label} ? $args{old_label} : 'original';
  my $new_label = defined $args{new_label} ? $args{new_label} : 'tidied';
  my $context   = defined $args{context}   ? $args{context}   : 3;

  return '' if $old eq $new;

  my @old = split /\n/, $old, -1;
  my @new = split /\n/, $new, -1;

  my @ops   = _diff_ops( \@old, \@new );
  my @hunks = _group_hunks( \@ops, $context );

  return '' unless @hunks;

  my $diff = '';
  $diff .= "--- $old_label\n";
  $diff .= "+++ $new_label\n";
  $diff .= _render_hunks( \@hunks );

  return $diff;
}

sub _diff_ops ( $old, $new ) {
  my $m = @$old;
  my $n = @$new;

  my @lcs;

  for my $i ( 0 .. $m ) {
    $lcs[$i][0] = 0;
  }

  for my $j ( 0 .. $n ) {
    $lcs[0][$j] = 0;
  }

  for my $i ( 1 .. $m ) {
    for my $j ( 1 .. $n ) {
      if ( $old->[ $i - 1 ] eq $new->[ $j - 1 ] ) {
        $lcs[$i][$j] = $lcs[ $i - 1 ][ $j - 1 ] + 1;
      }
      else {
        my $up   = $lcs[ $i - 1 ][$j];
        my $left = $lcs[$i][ $j - 1 ];
        $lcs[$i][$j] = $up >= $left ? $up : $left;
      }
    }
  }

  return _backtrack_ops( $old, $new, \@lcs, $m, $n );
}

sub _backtrack_ops ( $old, $new, $lcs, $i, $j ) {
  my @ops;

  while ( $i > 0 || $j > 0 ) {
    if ( $i > 0 && $j > 0 && $old->[ $i - 1 ] eq $new->[ $j - 1 ] ) {
      unshift @ops, [ equal => $old->[ $i - 1 ] ];
      $i--;
      $j--;
    }
    elsif ( $j > 0 && ( $i == 0 || $lcs->[$i][ $j - 1 ] >= $lcs->[ $i - 1 ][$j] ) ) {
      unshift @ops, [ insert => $new->[ $j - 1 ] ];
      $j--;
    }
    else {
      unshift @ops, [ delete => $old->[ $i - 1 ] ];
      $i--;
    }
  }

  return @ops;
}

sub _group_hunks ( $ops, $context ) {
  my @hunks;
  my @pending_equal;
  my @current;

  my $old_line = 1;
  my $new_line = 1;

  for my $op (@$ops) {
    my ( $kind, $text ) = @$op;

    if ( $kind eq 'equal' ) {
      my $entry = {
        kind     => 'equal',
        text     => $text,
        old_line => $old_line,
        new_line => $new_line,
      };

      $old_line++;
      $new_line++;

      if (@current) {
        push @pending_equal, $entry;

        if ( @pending_equal > ( $context * 2 ) ) {
          push @current, @pending_equal[ 0 .. $context - 1 ] if $context > 0;
          push @hunks, _finalize_hunk( \@current );

          @current       = ();
          @pending_equal = @pending_equal[ @pending_equal - $context .. $#pending_equal ];
        }
      }

      next;
    }

    if ( !@current ) {
      if (@pending_equal) {
        my $start = @pending_equal > $context ? @pending_equal - $context : 0;
        push @current, @pending_equal[ $start .. $#pending_equal ];
      }
    }
    else {
      push @current, @pending_equal if @pending_equal;
    }

    @pending_equal = ();

    my $entry = {
      kind     => $kind,
      text     => $text,
      old_line => $kind eq 'insert' ? undef : $old_line,
      new_line => $kind eq 'delete' ? undef : $new_line,
    };

    push @current, $entry;

    $old_line++ if $kind eq 'delete';
    $new_line++ if $kind eq 'insert';
  }

  if (@current) {
    if (@pending_equal) {
      my $end = @pending_equal > $context ? $context - 1 : $#pending_equal;
      push @current, @pending_equal[ 0 .. $end ] if $end >= 0;
    }

    push @hunks, _finalize_hunk( \@current );
  }

  return @hunks;
}

sub _finalize_hunk ( $entries ) {
  my @chunk = @$entries;

  my @old_lines = grep { defined $_->{old_line} } @chunk;
  my @new_lines = grep { defined $_->{new_line} } @chunk;

  my $old_start = @old_lines ? $old_lines[0]{old_line} : 0;
  my $new_start = @new_lines ? $new_lines[0]{new_line} : 0;

  my $old_count = 0;
  my $new_count = 0;

  for my $entry (@chunk) {
    if ( $entry->{kind} eq 'equal' ) {
      $old_count++;
      $new_count++;
    }
    elsif ( $entry->{kind} eq 'delete' ) {
      $old_count++;
    }
    elsif ( $entry->{kind} eq 'insert' ) {
      $new_count++;
    }
  }

  return {
    old_start => $old_start,
    old_count => $old_count,
    new_start => $new_start,
    new_count => $new_count,
    entries   => \@chunk,
  };
}

sub _render_hunks ( $hunks ) {
  my $out = '';

  for my $hunk (@$hunks) {
    $out .= sprintf(
      "@@ -%s +%s @@\n",
      _format_range( $hunk->{old_start}, $hunk->{old_count} ),
      _format_range( $hunk->{new_start}, $hunk->{new_count} ),
    );

    for my $entry ( @{ $hunk->{entries} } ) {
      if ( $entry->{kind} eq 'equal' ) {
        $out .= " $entry->{text}\n";
      }
      elsif ( $entry->{kind} eq 'delete' ) {
        $out .= "-$entry->{text}\n";
      }
      elsif ( $entry->{kind} eq 'insert' ) {
        $out .= "+$entry->{text}\n";
      }
      else {
        die "Unknown diff op kind '$entry->{kind}'";
      }
    }
  }

  return $out;
}

sub _format_range ( $start, $count ) {
  $start //= 0;
  $count //= 0;

  return $count == 1 ? $start : "$start,$count";
}

1;

__END__

=pod

=head1 NAME

Mojo::PrettyTidy::Diff - Minimal unified diff support for Mojo::PrettyTidy

=head1 SYNOPSIS

    use Mojo::PrettyTidy::Diff qw(unified_diff);

    my $diff = unified_diff(
      old       => $before,
      new       => $after,
      old_label => 'file.html.ep (original)',
      new_label => 'file.html.ep (tidied)',
      context   => 3,
    );

=head1 DESCRIPTION

This module provides a small pure-Perl line-based diff suitable for
showing what C<Mojo::PrettyTidy> would change.

It is intentionally minimal and is not intended to be a full general
purpose replacement for system C<diff>.

=head1 FUNCTIONS

=head2 unified_diff

Returns an empty string if the inputs are identical. Otherwise returns
a minimal unified-style diff as a string.

Recognized arguments include:

=over 4

=item * C<old>

=item * C<new>

=item * C<old_label>

=item * C<new_label>

=item * C<context>

Number of unchanged context lines to include around each changed hunk.
Defaults to C<3>.

=back

=head1 LICENSE

Same terms as Perl itself.

=cut
