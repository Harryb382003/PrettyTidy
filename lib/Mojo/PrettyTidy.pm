package Mojo::PrettyTidy;

use 5.40.0;
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

  $output =~ s/[ \t]+$//mg;
  $output =~ s/\r\n/\n/g;
  $output =~ s/\r/\n/g;
  $output =~ s/\n*\z/\n/;

  return $output;
}

sub check {
  my ( $self, $input ) = @_;

  my $output = $self->tidy( $input );

  return $output eq ( defined $input ? $input : '' ) ? 1 : 0;
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

=head1 DESIGN GOALS

This module is intended to be safe to invoke from editors and command
line tools in a style similar to C<perltidy>.

=head1 AUTHOR

Harry Bennett

=head1 LICENSE

Same terms as Perl itself.

=cut
