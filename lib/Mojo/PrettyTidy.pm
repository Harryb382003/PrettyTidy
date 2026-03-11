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
  my $text = defined $input ? $input : '';

  $text = $self->_normalize_line_endings( $text );
  $text = $self->_strip_trailing_whitespace( $text );
  $text = $self->_apply_basic_indentation( $text );
  $text = $self->_cohere_percent_clusters( $text );
  $text = $self->_cohere_mixed_ep_micro_blocks( $text );
  $text = $self->_ensure_final_newline( $text );

  return $text;
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
  my $style_inner_level     = 0;
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
        my $tail_has_closing_tag =
            _inline_style_tail_has_closing_tag( $trimmed );

        push @out,
            $self->_format_inline_style_block( \@inline_style_lines,
                                               $inline_style_base, $step, );

        $level-- if $tail_has_closing_tag && $level > 0;

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
    if ( _is_html_line_with_ep( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _effective_ep_indent( $ep_level ) ) ) . $trimmed;
      next;
    }

    if ( _line_contains_ep( $line ) ) {
      $ep_level-- if _ep_closes_before( $line ) && $ep_level > 0;

      if ( _is_ep_control_line( $line ) ) {
        my $ep_line = _normalize_percent_line( $trimmed );
        push @out, ( $step x $level ) . $ep_line;
      }
      elsif ( $line =~ /^\s*%/ ) {
        my $ep_line       = _normalize_percent_line( $trimmed );
        my $content_depth = $level + _effective_ep_indent( $ep_level );
        push @out, ( $step x $content_depth ) . $ep_line;
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
        $in_style_block    = 0;
        $style_inner_level = 0;
        next;
      }

      my $line_level = $style_inner_level;

      # Dedent closing-brace lines before printing
      if ( $trimmed =~ /^\}/ ) {
        $line_level-- if $line_level > 0;
      }

      push @out, ( $step x ( $base + 1 + $line_level ) ) . $trimmed;

      # One-line brace rules stay effectively unchanged
      my $opens  = () = $trimmed =~ /\{/g;
      my $closes = () = $trimmed =~ /\}/g;

      $style_inner_level += $opens - $closes;
      $style_inner_level = 0 if $style_inner_level < 0;

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
      $in_style_block    = 1 unless _is_style_end_line( $trimmed );
      $style_inner_level = 0;
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

sub _cohere_mixed_ep_micro_blocks ( $self, $text ) {
  my @lines = split /\n/, $text, -1;
  my @out;
  my $i = 0;

  while ( $i <= $#lines ) {
    my $line = $lines[$i];

    unless ( _is_percent_line( $line ) || _is_ep_output_line( $line ) ) {
      push @out, $line;
      $i++;
      next;
    }

    my @block;

    while ( $i <= $#lines ) {
      my $cur = $lines[$i];
      last unless _is_percent_line( $cur ) || _is_ep_output_line( $cur );
      push @block, $cur;
      $i++;
    }

    my $has_controlish = grep { _is_percent_controlish_line( $_ ) } @block;
    my $has_ep_output  = grep { _is_ep_output_line( $_ ) } @block;
    my $has_closer     = grep { _is_percent_closer_line( $_ ) } @block;

    if ( $has_controlish && $has_ep_output && $has_closer ) {
      my $target;
      for my $l ( @block ) {
        next unless _is_percent_line( $l );
        $target = _percent_indent( $l );
        last;
      }
      $target //= 0;

      for my $l ( @block ) {
        if ( _is_percent_line( $l ) ) {
          $l =~ s/^\s*(%.*)$/' ' x $target . $1/e;
          push @out, $l;
        }
        elsif ( _is_ep_output_line( $l ) ) {
          my $trim = $l;
          $trim =~ s/^\s+//;
          push @out, ( ' ' x ( $target + $self->{indent_width} ) ) . $trim;
        }
        else {
          push @out, $l;
        }
      }
    }
    else {
      push @out, @block;
    }
  }

  return join "\n", @out;
}

sub _cohere_percent_clusters ( $self, $text ) {
  my @lines = split /\n/, $text, -1;
  my @out;
  my $i = 0;

  while ( $i <= $#lines ) {
    if ( !_is_percent_line( $lines[$i] ) ) {
      push @out, $lines[ $i++ ];
      next;
    }

    my @cluster;

    while ( $i <= $#lines && _is_percent_line( $lines[$i] ) ) {
      push @cluster, $lines[$i];
      $i++;
    }

    my $has_controlish = grep { _is_percent_controlish_line( $_ ) } @cluster;
    my $has_closer     = grep { _is_percent_closer_line( $_ ) } @cluster;
    my $starts_with_sub =
        @cluster && _is_percent_sub_opener_line( $cluster[0] );

    if ( $has_controlish && $has_closer && !$starts_with_sub ) {
      my $target;
      for my $l ( @cluster ) {
        next unless _is_percent_line( $l );
        my $n = _percent_indent( $l );
        $target = $n if !defined( $target ) || $n < $target;
      }
      $target //= 0;

      for my $l ( @cluster ) {
        $l =~ s/^\s*(%.*)$/' ' x $target . $1/e;
        push @out, $l;
      }
    }
    else {
      push @out, @cluster;
    }
  }

  return join "\n", @out;
}

sub _effective_ep_indent ( $ep_level ) {
  return $ep_level > 0 ? 1 : 0;
}

sub _ensure_final_newline ( $self, $text ) {
  $text = '' unless defined $text;

  $text =~ s/\n*\z/\n/;

  return $text;
}

sub _ep_closes_before ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%\s*}/ ? 1 : 0;
}

sub _ep_opens_after ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%.*\{\s*$/ ? 1 : 0;
}

sub _format_inline_style_block ( $self, $lines, $base, $step ) {
  my @out;
  return @out unless $lines && @$lines;

  my @trimmed = map {
    my $x = $_;
    $x =~ s/^\s+//;
    $x =~ s/\s+$//;
    $x;
  } @$lines;

  return ( ( $step x $base ) . $trimmed[0] ) if @trimmed == 1;

  my $last = pop @trimmed;
  my ( $kind, $style_close, $content, $closing_tag ) =
      _split_inline_style_tail( $last );

  # opener
  push @out, ( $step x $base ) . shift @trimmed;

  # middle declaration lines
  for my $line ( @trimmed ) {
    push @out, ( $step x ( $base + 1 ) ) . $line;
  }

  # fallback
  if ( !defined $kind ) {
    push @out, ( $step x ( $base + 1 ) ) . $last;
    return @out;
  }

  if ( $kind eq 'bare_close_only' ) {
    if ( @out ) {
      $out[-1] .= $style_close;
    }
    else {
      push @out, ( $step x $base ) . $style_close;
    }
    return @out;
  }

  if ( $kind eq 'style_close_on_declaration' ) {
    push @out, ( $step x ( $base + 1 ) ) . $style_close;
    return @out;
  }

  if ( $kind eq 'closing_tag_only' ) {
    push @out, ( $step x ( $base + 1 ) ) . $style_close;
    push @out, ( $step x $base ) . $closing_tag if defined $closing_tag;
    return @out;
  }

  if ( $kind eq 'text_and_closing_tag' ) {
    push @out, ( $step x ( $base + 1 ) ) . $style_close;
    push @out, ( $step x ( $base + 1 ) ) . $content
        if defined $content && length $content;
    push @out, ( $step x $base ) . $closing_tag
        if defined $closing_tag && length $closing_tag;
    return @out;
  }

  if ( $kind eq 'bare_close_closing_tag' ) {
    if ( @out ) {
      $out[-1] .= $style_close;
    }
    else {
      push @out, ( $step x $base ) . $style_close;
    }
    push @out, ( $step x $base ) . $closing_tag
        if defined $closing_tag && length $closing_tag;
    return @out;
  }

  if ( $kind eq 'bare_close_text_and_closing_tag' ) {
    if ( @out ) {
      $out[-1] .= $style_close;
    }
    else {
      push @out, ( $step x $base ) . $style_close;
    }
    push @out, ( $step x ( $base + 1 ) ) . $content
        if defined $content && length $content;
    push @out, ( $step x $base ) . $closing_tag
        if defined $closing_tag && length $closing_tag;
    return @out;
  }

  return @out;
}

sub _inline_style_tag_name ( $line ) {
  return unless defined $line;
  my ( $tag ) = $line =~ /^\s*<([A-Za-z][A-Za-z0-9:_-]*)\b/;
  return $tag;
}

sub _inline_style_tail_has_closing_tag ( $line ) {
  return 0 unless defined $line;
  return $line =~ /<\/[A-Za-z][A-Za-z0-9:_-]*>\s*$/ ? 1 : 0;
}

sub _is_doctype_line ( $line ) {
  return $line =~ /^\s*<!DOCTYPE\b/i ? 1 : 0;
}

sub _is_ep_control_line ( $line ) {
  return 0 unless defined $line;
  return 0 unless $line =~ /^\s*%/;

  return 1 if $line =~ /^\s*%\s*}/;
  return 1 if $line =~ /^\s*%\s*(?:if|elsif|else|for|foreach|while|unless)\b/;

  return 0;
}

sub _is_ep_output_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*<%=[\s\S]*%>\s*$/ ? 1 : 0;
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
  return 0 unless defined $line;
  return $line =~ /^\s*<[A-Za-z][A-Za-z0-9:_-]*\b.*\bstyle="\s*$/ ? 1 : 0;
}

sub _is_inline_style_end_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /">\s*$/ || $line =~ /">.*$/;
}

sub _is_inline_style_closing_only_line ( $line ) {
  return $line =~ /^\s*">\s*$/ ? 1 : 0;
}

sub _line_indent ( $line ) {
  return 0 unless defined $line;
  $line =~ /^(\s*)/;
  return length( $1 // '' );
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

sub _is_percent_closer_line ( $line ) {
  return defined $line && $line =~ /^\s*%\s*}/ ? 1 : 0;
}

sub _is_percent_comment_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%\s*#/ ? 1 : 0;
}

sub _is_percent_controlish_line ( $line ) {
  return 0 unless defined $line;
  return 1 if $line =~ /^\s*%\s*#/;
  return 1 if $line =~ /^\s*%\s*(?:if|elsif|else|for|foreach|while|unless)\b/;
  return 1 if $line =~ /^\s*%\s*}/;
  return 0;
}

sub _is_percent_sub_opener_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%\s*.*\bsub\s*\{\s*$/ ? 1 : 0;
}

sub _is_percent_line ( $line ) {
  return defined $line && $line =~ /^\s*%/ ? 1 : 0;
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

sub _normalize_percent_line ( $line ) {
  return $line unless defined $line;
  $line =~ s/^\s*%\s*/% /;
  return $line;
}

sub _percent_indent ( $line ) {
  return 0 unless defined $line;
  $line =~ /^(\s*)%/;
  return defined $1 ? length( $1 ) : 0;
}

sub _split_inline_style_tail ( $line ) {
  return unless defined $line;

  my $trimmed = $line;
  $trimmed =~ s/^\s+//;
  $trimmed =~ s/\s+$//;

  # final declaration + close + text + closing tag
  if ( $trimmed =~ /^(.*?;">)([^<]+)(<\/[A-Za-z][A-Za-z0-9:_-]*>\s*)$/ ) {
    return ( 'text_and_closing_tag', $1, $2, $3 );
  }

  # final declaration + close + closing tag
  if ( $trimmed =~ /^(.*?;">)(<\/[A-Za-z][A-Za-z0-9:_-]*>\s*)$/ ) {
    return ( 'closing_tag_only', $1, undef, $2 );
  }

  # bare close + text + closing tag
  if ( $trimmed =~ /^">([^<]+)(<\/[A-Za-z][A-Za-z0-9:_-]*>\s*)$/ ) {
    return ( 'bare_close_text_and_closing_tag', '">', $1, $2 );
  }

  # bare close + closing tag
  if ( $trimmed =~ /^">(<\/[A-Za-z][A-Za-z0-9:_-]*>\s*)$/ ) {
    return ( 'bare_close_closing_tag', '">', undef, $1 );
  }

  # final declaration already ends with ">
  if ( $trimmed =~ /^(.*;">)\s*$/ ) {
    return ( 'style_close_on_declaration', $1, undef, undef );
  }

  # bare dangling close-only line
  if ( $trimmed =~ /^">\s*$/ ) {
    return ( 'bare_close_only', '">', undef, undef );
  }

  return;
}

sub _strip_trailing_whitespace ( $self, $text ) {
  $text = '' unless defined $text;

  $text =~ s/[ \t]+$//mg;

  return $text;
}

sub _is_percent_sub_opener_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%\s*.*\bsub\s*\{\s*$/ ? 1 : 0;
}

1;

__END__

=pod

=head1 NAME

mojo-prettytidy - Conservative tidy tool for Mojolicious .html.ep templates

=head1 SYNOPSIS

    mojo-prettytidy file.html.ep
    mojo-prettytidy --config path/to/config.json file.html.ep
    mojo-prettytidy --stdin < file.html.ep
    mojo-prettytidy --output parsed.file.html.ep file.html.ep
    mojo-prettytidy --check file.html.ep
    mojo-prettytidy --diff file.html.ep
    mojo-prettytidy --write file.html.ep
    mojo-prettytidy --write --backup file.html.ep
    mojo-prettytidy --write --backup --backup-ext=.orig file.html.ep
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

=head2 --config

Load default options from the specified JSON config file.

If no explicit C<--config> is given, C<mojo-prettytidy> will
auto-load C<.mojo-prettytidy.json> from the current working
directory if that file exists.

Command-line options override config values.

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

=head1 CONFIG FILE

Config files use JSON object syntax. Supported keys currently include:

=over 4

=item * C<indent_width>

=item * C<tab_width>

=item * C<prefix>

=item * C<outdir>

=back

Example:

    {
      "prefix": "pt.",
      "outdir": "share/samples/testing"
    }

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
