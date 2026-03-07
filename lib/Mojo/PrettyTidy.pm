package Mojo::PrettyTidy;

use v5.40.0;
use common::sense;
use feature 'signatures';

our $VERSION = '0.01';

sub new ( $class, %args ) {
  my $self = bless {
          indent_width => defined $args{indent_width} ? $args{indent_width} : 2,
          tab_width    => defined $args{tab_width}    ? $args{tab_width}    : 2,
  }, $class;

  return $self;
}

sub tidy ( $self, $input ) {
  $input = '' unless defined $input;

  my $output = $input;

  $output = $self->_normalize_line_endings( $output );
  $output = $self->_strip_trailing_whitespace( $output );
  $output = $self->_apply_basic_indentation( $output );
  $output = $self->_ensure_final_newline( $output );

  return $output;
}

sub check ( $self, $input ) {
  $input = '' unless defined $input;

  my $output = $self->tidy( $input );

  return $output eq $input ? 1 : 0;
}

sub _normalize_line_endings ( $self, $text ) {
  $text = '' unless defined $text;

  $text =~ s/\r\n/\n/g;
  $text =~ s/\r/\n/g;

  return $text;
}

sub _strip_trailing_whitespace ( $self, $text ) {
  $text = '' unless defined $text;

  $text =~ s/[ \t]+$//mg;

  return $text;
}

sub _apply_basic_indentation ( $self, $text ) {
  $text = '' unless defined $text;

  my @lines = split /\n/, $text, -1;
  my @out;
  my $level            = 0;
  my $step             = ' ' x $self->{indent_width};
  my $in_comment_block = 0;

  for my $line (@lines) {
    if ( $line =~ /^\s*$/ ) {
      push @out, '';
      next;
    }

    if ( _line_contains_ep($line) ) {
      push @out, $line;
      next;
    }

    my $trimmed = $line;
    $trimmed =~ s/^\s+//;
    $trimmed =~ s/\s+$//;

    if ($in_comment_block) {
      push @out, ( $step x $level ) . $trimmed;
      $in_comment_block = 0 if _is_html_comment_end_line($trimmed);
      next;
    }

    if ( _is_html_comment_start_line($trimmed) ) {
      push @out, ( $step x $level ) . $trimmed;
      $in_comment_block = 1 unless _is_html_comment_line($trimmed);
      next;
    }

    if ( _is_doctype_line($trimmed) ) {
      push @out, ( $step x $level ) . $trimmed;
      next;
    }

    if ( _is_html_comment_line($trimmed) ) {
      push @out, ( $step x $level ) . $trimmed;
      next;
    }

    if ( _is_pure_closing_tag_line($trimmed) ) {
      $level-- if $level > 0;
      push @out, ( $step x $level ) . $trimmed;
      next;
    }

    if ( _is_pure_opening_tag_line($trimmed) ) {
      push @out, ( $step x $level ) . $trimmed;
      $level++;
      next;
    }

    if ( _is_pure_void_tag_line($trimmed) ) {
      push @out, ( $step x $level ) . $trimmed;
      next;
    }

    if ( _is_plain_text_line($trimmed) ) {
      push @out, ( $step x $level ) . $trimmed;
      next;
    }

    push @out, $trimmed;
  }

  return join "\n", @out;
}

sub _is_doctype_line ( $line ) {
  return $line =~ /^\s*<!DOCTYPE\b/i ? 1 : 0;
}

sub _is_html_comment_line ( $line ) {
  return $line =~ /^\s*<!--.*-->\s*$/ ? 1 : 0;
}

sub _is_html_comment_end_line ($line) {
  return $line =~ /-->\s*$/ ? 1 : 0;
}

sub _is_html_comment_start_line ($line) {
  return $line =~ /^\s*<!--/ ? 1 : 0;
}

sub _is_plain_text_line ( $line ) {
  return 0 if !defined $line || $line eq '';
  return 0 if _line_contains_ep( $line );
  return 0 if $line =~ /</;
  return 1;
}

sub _is_pure_opening_tag_line ( $line ) {
  return 0 if $line =~ /<%/;
  return 0 if $line =~ m{^</};

  return $line =~ m{^<([A-Za-z][A-Za-z0-9:_-]*)(?:\s+[^<>]*)?>\s*$}
      ? !_is_void_html_tag( $1 )
      : 0;
}

sub _is_pure_closing_tag_line ( $line ) {
  return $line =~ m{^</[A-Za-z][A-Za-z0-9:_-]*>\s*$} ? 1 : 0;
}

sub _is_pure_void_tag_line ( $line ) {
  return 0 if $line =~ /<%/;

  return $line =~ m{^<([A-Za-z][A-Za-z0-9:_-]*)(?:\s+[^<>]*)?/?>\s*$}
      ? _is_void_html_tag( $1 ) || $line =~ m{/>$}
      : 0;
}

sub _is_void_html_tag ( $tag ) {
  state %void = map { $_ => 1 } qw(
      area base br col embed hr img input link meta param source track wbr
  );

  return $void{lc $tag} ? 1 : 0;
}

sub _ensure_final_newline ( $self, $text ) {
  $text = '' unless defined $text;

  $text =~ s/\n*\z/\n/;

  return $text;
}

sub _line_contains_ep ( $line ) {
  return $line =~ /<%|^\s*%/ ? 1 : 0;
}

1;

__END__

=pod

=head1 NAME

Mojo::PrettyTidy - Conservative tidy tool for Mojolicious .html.ep templates

=head1 SYNOPSIS

    use Mojo::PrettyTidy;

    my $pt = Mojo::PrettyTidy->new(
      indent_width => 2,
      tab_width    => 2,
    );

    my $output = $pt->tidy($input);

    if ( !$pt->check($input) ) {
      print "changes would be made\n";
    }

=head1 DESCRIPTION

C<Mojo::PrettyTidy> is a conservative tidy tool for Mojolicious
Embedded Perl template files, especially C<.html.ep>.

The initial focus is safe normalization and indentation rather than
aggressive formatting. Early versions aim to preserve template
semantics while performing low-risk cleanup.

=head1 METHODS

=head2 new

    my $pt = Mojo::PrettyTidy->new(%args);

Constructs a new formatter object.

=head2 tidy

    my $output = $pt->tidy($input);

Returns a conservatively tidied version of the input text.

Current behavior includes:

=over 4

=item * normalize line endings to LF

=item * remove trailing horizontal whitespace

=item * apply a narrow indentation pass to obvious HTML-only lines

=item * ensure exactly one trailing newline at end of file

=back

=head2 check

    my $ok = $pt->check($input);

Returns true if C<tidy> would leave the input unchanged.

=head1 DESIGN GOALS

This module is intended to be safe to invoke from editors and command
line tools in a style similar to C<perltidy>.

=head1 AUTHOR

Harry Bennett

=head1 LICENSE

Same terms as Perl itself.

=cut
