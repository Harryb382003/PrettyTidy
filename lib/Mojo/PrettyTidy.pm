package Mojo::PrettyTidy;

use v5.40.0;
use common::sense;

our $VERSION = '0.01';

sub new {
  my ( $class, %args ) = @_;

  my $self = bless {
          indent_width => defined $args{indent_width} ? $args{indent_width} : 2,
          tab_width    => defined $args{tab_width}    ? $args{tab_width}    : 2,
  }, $class;

  return $self;
}

sub tidy {
  my ( $self, $input ) = @_;

  $input = '' unless defined $input;

  my $output = $input;

  $output = $self->_normalize_line_endings( $output );
  $output = $self->_strip_trailing_whitespace( $output );
  $output = $self->_ensure_final_newline( $output );

  return $output;
}

sub check {
  my ( $self, $input ) = @_;

  $input = '' unless defined $input;

  my $output = $self->tidy( $input );

  return $output eq $input ? 1 : 0;
}

sub _normalize_line_endings {
  my ( $self, $text ) = @_;

  $text = '' unless defined $text;

  $text =~ s/\r\n/\n/g;
  $text =~ s/\r/\n/g;

  return $text;
}

sub _strip_trailing_whitespace {
  my ( $self, $text ) = @_;

  $text = '' unless defined $text;

  $text =~ s/[ \t]+$//mg;

  return $text;
}

sub _ensure_final_newline {
  my ( $self, $text ) = @_;

  $text = '' unless defined $text;

  $text =~ s/\n*\z/\n/;

  return $text;
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

The initial focus is safe normalization rather than aggressive
formatting. Early versions aim to preserve template semantics while
performing low-risk cleanup such as line-ending normalization,
trailing whitespace removal, and ensuring a final newline.

=head1 METHODS

=head2 new

    my $pt = Mojo::PrettyTidy->new(%args);

Constructs a new formatter object.

Recognized options:

=over 4

=item * indent_width

Indent width to use for future indentation features. Default is C<2>.

=item * tab_width

Tab width metadata for future formatting features. Default is C<2>.

=back

=head2 tidy

    my $output = $pt->tidy($input);

Returns a normalized version of the input text.

In version 0.01 this method performs only conservative cleanup:

=over 4

=item * normalize line endings to LF

=item * remove trailing horizontal whitespace

=item * ensure exactly one trailing newline at end of file

=back

=head2 check

    my $ok = $pt->check($input);

Returns true if C<tidy> would leave the input unchanged, false if
changes would be made.

=head1 INTERNAL METHODS

These methods are currently private implementation details and may
change without notice.

=head2 _normalize_line_endings

Normalizes CRLF and CR line endings to LF.

=head2 _strip_trailing_whitespace

Removes trailing spaces and tabs at end of line.

=head2 _ensure_final_newline

Ensures the document ends with exactly one newline.

=head1 DESIGN GOALS

This module is intended to be safe to invoke from editors and command
line tools in a style similar to C<perltidy>.

=head1 AUTHOR

Harry Bennett

=head1 LICENSE

Same terms as Perl itself.

=cut
