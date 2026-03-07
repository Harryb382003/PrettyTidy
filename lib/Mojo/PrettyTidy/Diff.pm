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

  return '' if $old eq $new;

  my @old = split /\n/, $old, -1;
  my @new = split /\n/, $new, -1;

  my @ops = _diff_ops( \@old, \@new );

  my $old_count = @old;
  my $new_count = @new;

  my $diff = '';
  $diff .= "--- $old_label\n";
  $diff .= "+++ $new_label\n";
  $diff .= sprintf "@@ -1,%d +1,%d @@\n", $old_count, $new_count;

  for my $op ( @ops ) {
    my ( $kind, $line ) = @$op;

    if ( $kind eq 'equal' ) {
      $diff .= " $line\n";
    }
    elsif ( $kind eq 'delete' ) {
      $diff .= "-$line\n";
    }
    elsif ( $kind eq 'insert' ) {
      $diff .= "+$line\n";
    }
    else {
      die "Unknown diff op kind '$kind'";
    }
  }

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

  my @ops = _backtrack_ops( $old, $new, \@lcs, $m, $n );

  return @ops;
}

sub _backtrack_ops ( $old, $new, $lcs, $i, $j ) {
  my @ops;

  while ( $i > 0 || $j > 0 ) {
    if ( $i > 0 && $j > 0 && $old->[ $i - 1 ] eq $new->[ $j - 1 ] ) {
      unshift @ops, [ equal => $old->[ $i - 1 ] ];
      $i--;
      $j--;
    }
    elsif ( $j > 0
            && ( $i == 0 || $lcs->[$i][ $j - 1 ] >= $lcs->[ $i - 1 ][$j] ) )
    {
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

=head1 LICENSE

Same terms as Perl itself.

=cut
