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

sub _apply_basic_indentation ( $self, $text ) {
  $text = '' unless defined $text;

  my @lines = split /\n/, $text, -1;
  my @out;

  my $level                 = 0;
  my $ep_level              = 0;
  my $step                  = ' ' x $self->{indent_width};
  my $in_comment_block      = 0;
  my $in_script_block       = 0;
  my $in_style_block        = 0;
  my $in_inline_style_block = 0;
  my $inline_style_base     = 0;
  my $in_multiline_tag_open = 0;
  my $multiline_tag_base    = 0;
  my $multiline_tag_opens   = 0;
  my @inline_style_lines;

  for my $line ( @lines ) {
    my $trimmed = $line;
    $trimmed =~ s/^\s+//;
    $trimmed =~ s/\s+$//;

    if ( $in_inline_style_block ) {
      push @inline_style_lines, $line;

      if ( _is_inline_style_end_line( $trimmed ) ) {
        push @out,
            $self->_format_inline_style_block( \@inline_style_lines,
                                               $inline_style_base, $step, );

        @inline_style_lines    = ();
        $in_inline_style_block = 0;
      }

      next;
    }

    if ( $line =~ /^\s*$/ ) {
      push @out, '';
      next;
    }

    if ( $in_multiline_tag_open ) {
      push @out, ( $step x ( $multiline_tag_base + 1 ) ) . $trimmed;

      if ( _is_tag_end_line( $trimmed ) ) {
        $level++ if $multiline_tag_opens && $trimmed !~ /\/>\s*$/;
        $in_multiline_tag_open = 0;
        $multiline_tag_opens   = 0;
      }

      next;
    }

    if ( _is_html_line_with_ep( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      next;
    }

    if ( _line_contains_ep( $line ) ) {
      $ep_level-- if _ep_closes_before( $line ) && $ep_level > 0;

      if ( _is_ep_control_line( $line ) ) {
        push @out, ( $step x $level ) . $trimmed;
      }
      elsif ( $line =~ /^\s*%/ ) {
        my $content_depth = $level + _effective_ep_indent( $ep_level );
        push @out, ( $step x $content_depth ) . $trimmed;
      }
      else {
        push @out,
            ( $step x ( $level + _effective_ep_indent( $ep_level ) ) )
            . $trimmed;
      }

      $ep_level++ if _ep_opens_after( $line );
      next;
    }

    if ( _is_multiline_tag_start_line( $trimmed ) ) {
      my ( $tag ) = $trimmed =~ /^\s*<([A-Za-z][A-Za-z0-9:_-]*)\b/;

      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;

      $in_multiline_tag_open = 1;
      $multiline_tag_base    = $level + _effective_ep_indent( $ep_level );
      $multiline_tag_opens =
          ( defined $tag
            && !_is_void_html_or_self_closing_tag( $tag, $trimmed ) )
          ? 1
          : 0;

      next;
    }

    if ( $in_comment_block ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      $in_comment_block = 0 if _is_html_comment_end_line( $trimmed );
      next;
    }

    if ( $in_script_block ) {
      my $base = $level + _effective_ep_indent( $ep_level );

      if ( _is_script_end_line( $trimmed ) ) {
        push @out, ( $step x $base ) . $trimmed;
        $in_script_block = 0;
      }
      else {
        push @out, ( $step x ( $base + 1 ) ) . $trimmed;
      }

      next;
    }

    if ( $in_style_block ) {
      my $base = $level + _effective_ep_indent( $ep_level );

      if ( _is_style_end_line( $trimmed ) ) {
        push @out, ( $step x $base ) . $trimmed;
        $in_style_block = 0;
      }
      else {
        push @out, ( $step x ( $base + 1 ) ) . $trimmed;
      }

      next;
    }

    if ( _is_inline_style_start_line( $trimmed ) ) {
      my $tag = _inline_style_tag_name( $trimmed );

      $in_inline_style_block = 1;
      $inline_style_base     = $level + $ep_level;
      @inline_style_lines    = ( $line );

      if ( defined $tag
           && !_is_void_html_or_self_closing_tag( $tag, $trimmed ) )
      {
        $level++;
      }

      next;
    }

    if ( _is_html_comment_start_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      $in_comment_block = 1 unless _is_html_comment_line( $trimmed );
      next;
    }

    if ( _is_multiline_tag_start_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;

      $in_multiline_tag_open = 1;
      $multiline_tag_base    = $level + _effective_ep_indent( $ep_level );

      next;
    }

    if ( _is_script_start_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      $in_script_block = 1 unless _is_script_end_line( $trimmed );
      next;
    }

    if ( _is_style_start_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      $in_style_block = 1 unless _is_style_end_line( $trimmed );
      next;
    }

    if ( _is_doctype_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      next;
    }

    if ( _is_html_comment_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      next;
    }

    if ( _is_mixed_inline_html_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      next;
    }

    if ( _is_pure_closing_tag_line( $trimmed ) ) {
      $level-- if $level > 0;
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      next;
    }

    if ( _is_pure_opening_tag_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      $level++;
      next;
    }

    if ( _is_pure_void_tag_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      next;
    }

    if ( _is_plain_text_line( $trimmed ) ) {
      my $text_ep_depth = 0;

      if ( $ep_level > 0 ) {
        $text_ep_depth = $ep_level == 1 ? 1 : $ep_level - 1;
      }

      my $text_depth = $level + $text_ep_depth;

      push @out, ( $step x $text_depth ) . $trimmed;
      next;
    }

    push @out, $trimmed;
  }

  return join "\n", @out;
}

sub _ep_closes_before ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%\s*}/ ? 1 : 0;
}

sub _is_ep_control_line ( $line ) {
  return 0 unless defined $line;
  return 0 unless $line =~ /^\s*%/;

  return 1 if $line =~ /^\s*%\s*}/;
  return 1 if $line =~ /^\s*%\s*(?:if|elsif|else|for|foreach|while|unless)\b/;

  return 0;
}

sub _effective_ep_indent ( $ep_level ) {
  return $ep_level > 0 ? 1 : 0;
}

sub _ensure_final_newline ( $self, $text ) {
  $text = '' unless defined $text;

  $text =~ s/\n*\z/\n/;

  return $text;
}

sub _ep_opens_after ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%.*\{\s*$/ ? 1 : 0;
}

sub _format_inline_style_block ( $self, $lines, $base, $step ) {
  my $has_ep = grep { _line_contains_ep( $_ ) } @$lines;

  return @$lines if $has_ep;

  my @out;

  for my $i ( 0 .. $#$lines ) {
    my $line    = $lines->[$i];
    my $trimmed = $line;
    $trimmed =~ s/^\s+//;
    $trimmed =~ s/\s+$//;

    if ( $i == 0 ) {
      push @out, ( $step x $base ) . $trimmed;
    }
    elsif ( $i == $#$lines ) {
      if ( _is_inline_style_closing_only_line( $trimmed ) ) {
        push @out, ( $step x $base ) . $trimmed;
      }
      else {
        push @out, ( $step x ( $base + 1 ) ) . $trimmed;
      }
    }
    else {
      push @out, ( $step x ( $base + 1 ) ) . $trimmed;
    }
  }

  return @out;
}

sub _inline_style_tag_name ( $line ) {
  return $line =~ /^\s*<([A-Za-z][A-Za-z0-9:_-]*)\b[^>]*\bstyle="\s*$/
      ? $1
      : undef;
}

sub _is_doctype_line ( $line ) {
  return $line =~ /^\s*<!DOCTYPE\b/i ? 1 : 0;
}

sub _is_html_comment_line ( $line ) {
  return $line =~ /^\s*<!--.*-->\s*$/ ? 1 : 0;
}

sub _is_html_comment_end_line ( $line ) {
  return $line =~ /-->\s*$/ ? 1 : 0;
}

sub _is_html_comment_start_line ( $line ) {
  return $line =~ /^\s*<!--/ ? 1 : 0;
}

sub _is_html_line_with_ep ( $line ) {
  return 0 if !defined $line || $line eq '';
  return 0 unless $line =~ /^\s*</;
  return 0 if $line     =~ /^\s*<%[=%#]?/; # leading EP tag line stays untouched
  return 0 unless _line_contains_ep( $line );
  return 1;
}

sub _is_inline_style_start_line ( $line ) {
  return $line =~ /^\s*<[^>]+\bstyle="\s*$/ ? 1 : 0;
}

sub _is_inline_style_end_line ( $line ) {
  return $line =~ /">\s*$/ ? 1 : 0;
}

sub _is_inline_style_closing_only_line ( $line ) {
  return $line =~ /^\s*">\s*$/ ? 1 : 0;
}

sub _is_mixed_inline_html_line ( $line ) {
  return 0 if !defined $line || $line eq '';
  return 0 if _line_contains_ep( $line );

  return 0 if _is_pure_opening_tag_line( $line );
  return 0 if _is_pure_closing_tag_line( $line );
  return 0 if _is_pure_void_tag_line( $line );
  return 0 if _is_doctype_line( $line );
  return 0 if _is_html_comment_line( $line );

  return 1 if $line =~ /</ && $line =~ />/;

  return 0;
}

sub _is_multiline_tag_start_line ( $line ) {
  return 0 unless defined $line;
  return 0 if $line =~ /^\s*<%/;
  return 0 if _is_inline_style_start_line( $line );
  return $line =~ /^\s*<[^\/!][^>]*$/ ? 1 : 0;
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

sub _is_script_start_line ( $line ) {
  return $line =~ /^\s*<script\b[^>]*>\s*$/i ? 1 : 0;
}

sub _is_script_end_line ( $line ) {
  return $line =~ /^\s*<\/script>\s*$/i ? 1 : 0;
}

sub _is_style_start_line ( $line ) {
  return $line =~ /^\s*<style\b[^>]*>\s*$/i ? 1 : 0;
}

sub _is_style_end_line ( $line ) {
  return $line =~ /^\s*<\/style>\s*$/i ? 1 : 0;
}

sub _is_tag_end_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ />\s*$/ ? 1 : 0;
}

sub _is_void_html_tag ( $tag ) {
  state %void = map { $_ => 1 } qw(
      area base br col embed hr img input link meta param source track wbr
  );

  return $void{lc $tag} ? 1 : 0;
}

sub _is_void_html_or_self_closing_tag ( $tag, $line ) {
  return 1 if defined $line && $line =~ /\/>\s*$/;
  return _is_void_html_tag( $tag );
}

sub _line_contains_ep ( $line ) {
  return $line =~ /<%|^\s*%/ ? 1 : 0;
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

1;

__END__

=pod

=head1 NAME

mojo-prettytidy - Conservative tidy tool for Mojolicious .html.ep templates

=head1 SYNOPSIS

    mojo-prettytidy file.html.ep
    mojo-prettytidy --output parsed.file.html.ep file.html.ep
    mojo-prettytidy --check file.html.ep
    mojo-prettytidy --diff file.html.ep
    mojo-prettytidy --write file.html.ep
    mojo-prettytidy --write --backup file.html.ep
    mojo-prettytidy --write --backup --backup-ext=.orig file.html.ep
    mojo-prettytidy --stdin < file.html.ep
    mojo-prettytidy file1.html.ep file2.html.ep --prefix pt.
    mojo-prettytidy file1.html.ep file2.html.ep --prefix pt. --outdir parsed
    mojo-prettytidy templates --prefix pt. --outdir parsed
    mojo-prettytidy --version

=head1 DESCRIPTION

C<mojo-prettytidy> provides command-line access to L<Mojo::PrettyTidy>.

The command is intended to be editor-friendly and suitable for use
from tools such as Kate in a manner similar to C<perltidy>.

By default, the formatted result is written to standard output.

=head1 OPTIONS

=head2 --write, -w

Rewrite the input file in place.

=head2 --backup

When used with C<--write>, create a backup of the original file before
rewriting it.

=head2 --backup-ext

When used with C<--write --backup>, choose the backup suffix.
The default is C<.bak>.

=head2 --check, -c

Exit with status C<0> if the input file is already tidy, or C<1> if
changes would be made.

This option requires a single input file.

=head2 --diff

Print a minimal unified-style diff showing what would change, and exit
with status C<0> if no changes are needed or C<1> if differences are
found.

This option requires a single input file.

=head2 --output, -o

Write the tidied result to the specified output file instead of standard
output.

This option cannot be combined with C<--write>, C<--check>, or C<--diff>.
It is intended for single-input use.

=head2 --prefix, --pre

When writing multiple outputs, prefix generated filenames with the
specified string.

=head2 --outdir

When writing multiple outputs, place generated files in the specified
directory.

=head2 --stdin

Read input from standard input and write formatted output to standard
output.

=head2 --version, -v

Print the program version and exit.

=head2 --help, -h

Show brief help.

=head2 --man

Show full documentation.

=head1 DIRECTORY INPUT

When a positional input is a directory, C<mojo-prettytidy> scans it
non-recursively and processes matching C<.html.ep> files.

When multiple input files are processed, use one of:

=over 4

=item * C<--write>

Rewrite each file in place.

=item * C<--prefix>

Write sibling output files with prefixed names.

=item * C<--outdir>

Write generated files to the specified output directory.

=back

=head1 EXIT STATUS

=over 4

=item * C<0>

Success, or no changes needed in C<--check> or C<--diff> mode.

=item * C<1>

Changes would be made in C<--check> mode, or differences were found in
C<--diff> mode.

=item * C<2>

Command-line usage error.

=back

=head1 LICENSE

Same terms as Perl itself.

=head1 PROJECT HOME

https://github.com/Harryb382003/PrettyTidy

=cut
