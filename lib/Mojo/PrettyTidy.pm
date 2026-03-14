package Mojo::PrettyTidy;

use v5.40.0;
use common::sense;
use feature 'signatures';

our $VERSION = '0.01';

sub new ( $class, %args ) {
  my $self = bless {
          indent_width => defined $args{indent_width} ? $args{indent_width} : 2,
          tab_width    => defined $args{tab_width}    ? $args{tab_width}    : 2,
          columns      => defined $args{columns}      ? $args{columns}      : 0,
          attributes   => defined $args{attributes}   ? $args{attributes}   : 0,
  }, $class;

  return $self;
}

sub tidy ( $self, $input ) {
  my $text = defined $input ? $input : '';

  $text = $self->_base_normalize_line_endings( $text );
  $text = $self->_base_strip_trailing_whitespace( $text );

  if ( $self->{attributes} ) {
    $text = $self->_attrib_expand_preferred_elements( $text );
    $text = $self->_attrib_expand_preferred_multiline_anchor_openers( $text );
    $text = $self->_attrib_expand_preferred_multiline_button_openers( $text );
  }

  $text = $self->_base_apply_basic_indentation( $text );

  if ( $self->{columns} ) {
    $text = $self->_cols_apply_column_expansion( $text );
    $text = $self->_base_apply_basic_indentation( $text );
  }

  $text = $self->_base_cohere_percent_clusters( $text );
  $text = $self->_base_cohere_mixed_ep_micro_blocks( $text );
  $text = $self->_base_ensure_final_newline( $text );

  return $text;
}

sub check ( $self, $input ) {
  $input = '' unless defined $input;

  my $output = $self->tidy( $input );

  return $output eq $input ? 1 : 0;
}

############################
#
# --attrib operationa
#
############################

sub _attrib_expand_preferred_anchor_line ( $self, $line ) {
  return undef unless defined $line;

  my ( $indent, $attrs, $content ) = $line =~ m{
    ^(\s*)
    <a\b
    ((?:[^>"']|"[^"]*"|'[^']*')*)
    >
    (.*?)
    </a>\s*$
  }x;

  return undef unless defined $indent;
  return undef unless defined $content && length $content;

  my @attrs = _attrib_split_html_attributes( $attrs );
  return undef unless @attrs;

  my @out;
  my $first     = shift @attrs;
  my $step      = ' ' x $self->{indent_width};
  my $attr_step = $step . $step;

  if ( @attrs ) {
    push @out, $indent . '<a ' . $first;

    while ( @attrs > 1 ) {
      push @out, $indent . $attr_step . shift @attrs;
    }

    push @out, $indent . $attr_step . $attrs[0] . '>';
  }
  else {
    push @out, $indent . '<a ' . $first . '>';
  }

  push @out, $indent . $step . $content;
  push @out, $indent . '</a>';

  return join "\n", @out;
}

sub _attrib_expand_preferred_button_line ( $self, $line ) {
  return undef unless defined $line;

  my ( $indent, $attrs, $content ) = $line =~ m{
    ^(\s*)
    <button\b
    ((?:[^>"']|"[^"]*"|'[^']*')*)
    >
    (.*?)
    </button>\s*$
  }x;

  return undef unless defined $indent;
  return undef unless defined $content && length $content;

  my @attrs = _attrib_split_html_attributes( $attrs );
  return undef unless @attrs;

  my @out;
  my $first     = shift @attrs;
  my $step      = ' ' x $self->{indent_width};
  my $attr_step = $step . $step;

  if ( @attrs ) {
    push @out, $indent . '<button ' . $first;

    while ( @attrs > 1 ) {
      push @out, $indent . $attr_step . shift @attrs;
    }

    push @out, $indent . $attr_step . $attrs[0] . '>';
  }
  else {
    push @out, $indent . '<button ' . $first . '>';
  }

  push @out, $indent . $step . $content;
  push @out, $indent . '</button>';

  return join "\n", @out;
}

sub _attrib_expand_preferred_elements ( $self, $text ) {
  my @lines = split /\n/, $text, -1;
  my @out;

  for my $line ( @lines ) {
    my $expanded = $self->_attrib_expand_preferred_form_line( $line )
        // $self->_attrib_expand_preferred_button_line( $line )
        // $self->_attrib_expand_preferred_anchor_line( $line )
        // $self->_attrib_expand_preferred_input_line( $line );
    if ( defined $expanded ) {
      push @out, split /\n/, $expanded, -1;
    }
    else {
      push @out, $line;
    }
  }

  return join "\n", @out;
}

sub _attrib_expand_preferred_form_line ( $self, $line ) {
  return undef unless defined $line;

  my ( $indent, $attrs ) = $line =~ m{
    ^(\s*)
    <form\b
    ((?:[^>"']|"[^"]*"|'[^']*')*)
    >\s*$
  }x;

  return undef unless defined $indent;

  my @attrs = _attrib_split_html_attributes( $attrs );
  return undef unless @attrs;

  my @out;
  my $first     = shift @attrs;
  my $step      = ' ' x $self->{indent_width};
  my $attr_step = $step . $step;

  if ( @attrs ) {
    push @out, $indent . '<form ' . $first;

    while ( @attrs > 1 ) {
      push @out, $indent . $attr_step . shift @attrs;
    }

    push @out, $indent . $attr_step . $attrs[0] . '>';
  }
  else {
    push @out, $indent . '<form ' . $first . '>';
  }

  return join "\n", @out;
}

sub _attrib_expand_preferred_input_line ( $self, $line ) {
  return undef unless defined $line;

  my ( $indent, $attrs, $selfclose ) = $line =~ m{
    ^(\s*)
    <input\b
    ((?:[^>"']|"[^"]*"|'[^']*')*)
    \s*(/?)>\s*$
  }x;

  return undef unless defined $indent;

  my @attrs = _attrib_split_html_attributes( $attrs );
  return undef unless @attrs;

  my @out;
  my $first     = shift @attrs;
  my $step      = ' ' x $self->{indent_width};
  my $attr_step = $step . $step;
  my $close     = $selfclose ? ' />' : '>';

  if ( @attrs ) {
    push @out, $indent . '<input ' . $first;

    while ( @attrs > 1 ) {
      push @out, $indent . $attr_step . shift @attrs;
    }

    push @out, $indent . $attr_step . $attrs[0] . $close;
  }
  else {
    push @out, $indent . '<input ' . $first . $close;
  }

  return join "\n", @out;
}

sub _attrib_expand_preferred_multiline_anchor_chunk ( $self, $chunk ) {
  return undef unless $chunk && @$chunk;

  my $first = $chunk->[0];
  my ( $indent ) = $first =~ /^(\s*)/;
  $indent //= '';

  my $joined = join ' ', map {
    my $x = $_;
    $x =~ s/^\s+//;
    $x =~ s/\s+$//;
    $x;
  } @$chunk;

  return undef unless $joined =~ /^<a\b(.*)>\s*$/i;
  my $attrs = $1;

  my @attrs = _attrib_split_html_attributes( $attrs );
  return undef unless @attrs;

  my $step      = ' ' x $self->{indent_width};
  my $attr_step = $step . $step;

  my @out;
  my $first_attr = shift @attrs;

  if ( @attrs ) {
    push @out, $indent . '<a ' . $first_attr;

    while ( @attrs > 1 ) {
      push @out, $indent . $attr_step . shift @attrs;
    }

    push @out, $indent . $attr_step . $attrs[0] . '>';
  }
  else {
    push @out, $indent . '<a ' . $first_attr . '>';
  }

  return join "\n", @out;
}

sub _attrib_expand_preferred_multiline_anchor_openers ( $self, $text ) {
  my @lines = split /\n/, $text, -1;
  my @out;
  my $i = 0;

  while ( $i <= $#lines ) {
    my $line = $lines[$i];

    unless ( defined $line && $line =~ /^\s*<a\b/i && $line !~ />\s*$/ ) {
      push @out, $line;
      $i++;
      next;
    }

    my @chunk;

    while ( $i <= $#lines ) {
      push @chunk, $lines[$i];
      last if $lines[$i] =~ />\s*$/;
      $i++;
    }

    if ( $i <= $#lines && $lines[$i] =~ />\s*$/ ) {
      my $expanded =
          $self->_attrib_expand_preferred_multiline_anchor_chunk( \@chunk );
      if ( defined $expanded ) {
        push @out, split /\n/, $expanded, -1;
      }
      else {
        push @out, @chunk;
      }
      $i++;
      next;
    }

    push @out, @chunk;
    $i++;
  }

  return join "\n", @out;
}

sub _attrib_expand_preferred_multiline_button_chunk ( $self, $chunk ) {
  return undef unless $chunk && @$chunk;

  my $first = $chunk->[0];
  my ( $indent ) = $first =~ /^(\s*)/;
  $indent //= '';

  my $joined = join ' ', map {
    my $x = $_;
    $x =~ s/^\s+//;
    $x =~ s/\s+$//;
    $x;
  } @$chunk;

  return undef unless $joined =~ /^<button\b(.*)>\s*$/i;
  my $attrs = $1;

  my @attrs = _attrib_split_html_attributes( $attrs );
  return undef unless @attrs;

  my $step      = ' ' x $self->{indent_width};
  my $attr_step = $step . $step;

  my @out;
  my $first_attr = shift @attrs;

  if ( @attrs ) {
    push @out, $indent . '<button ' . $first_attr;

    while ( @attrs > 1 ) {
      push @out, $indent . $attr_step . shift @attrs;
    }

    push @out, $indent . $attr_step . $attrs[0] . '>';
  }
  else {
    push @out, $indent . '<button ' . $first_attr . '>';
  }

  return join "\n", @out;
}

sub _attrib_expand_preferred_multiline_button_openers ( $self, $text ) {
  my @lines = split /\n/, $text, -1;
  my @out;
  my $i = 0;

  while ( $i <= $#lines ) {
    my $line = $lines[$i];

    unless ( defined $line && $line =~ /^\s*<button\b/i && $line !~ />\s*$/ ) {
      push @out, $line;
      $i++;
      next;
    }

    my @chunk;
    my $start = $i;

    while ( $i <= $#lines ) {
      push @chunk, $lines[$i];
      last if $lines[$i] =~ />\s*$/;
      $i++;
    }

    if ( $i <= $#lines && $lines[$i] =~ />\s*$/ ) {
      my $expanded =
          $self->_attrib_expand_preferred_multiline_button_chunk( \@chunk );
      if ( defined $expanded ) {
        push @out, split /\n/, $expanded, -1;
      }
      else {
        push @out, @chunk;
      }
      $i++;
      next;
    }

    push @out, @chunk;
    $i++;
  }

  return join "\n", @out;
}

sub _attrib_format_inline_style_block ( $self, $lines, $base, $step ) {
  my @out;
  return @out unless $lines && @$lines;

  my @trimmed = map {
    my $x = $_;
    $x =~ s/^\s+//;
    $x =~ s/\s+$//;
    $x;
  } @$lines;

  return ( ( $step x $base ) . $trimmed[0] ) if @trimmed == 1;

  my $tag = _attrib_inline_style_block_tag_name( $trimmed[0] );

  my $style_body_levels = 2;
  $style_body_levels = 1 if defined $tag && $tag =~ /\Abutton\z/i;

  my $last = pop @trimmed;
  my ( $kind, $style_close, $content, $closing_tag ) =
      _attrib_split_inline_style_tail( $last );

  push @out, ( $step x $base ) . shift @trimmed;

  for my $line ( @trimmed ) {
    push @out, ( $step x ( $base + $style_body_levels ) ) . $line;
  }

  if ( !defined $kind ) {
    push @out, ( $step x ( $base + $style_body_levels ) ) . $last;
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
    push @out, ( $step x ( $base + $style_body_levels ) ) . $style_close;
    return @out;
  }

  if ( $kind eq 'closing_tag_only' ) {
    push @out, ( $step x ( $base + $style_body_levels ) ) . $style_close;
    push @out, ( $step x $base ) . $closing_tag if defined $closing_tag;
    return @out;
  }

  if ( $kind eq 'text_and_closing_tag' ) {
    push @out, ( $step x ( $base + $style_body_levels ) ) . $style_close;
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

sub _attrib_inline_style_block_tag_name ( $first_line ) {
  return undef unless defined $first_line;
  my ( $tag ) = $first_line =~ /^\s*<([A-Za-z][A-Za-z0-9:_-]*)\b/;
  return $tag;
}

sub _attrib_inline_style_tag_name ( $line ) {
  return unless defined $line;
  my ( $tag ) = $line =~ /^\s*<([A-Za-z][A-Za-z0-9:_-]*)\b/;
  return $tag;
}

sub _attrib_inline_style_tail_has_closing_tag ( $line ) {
  return 0 unless defined $line;
  return $line =~ /<\/[A-Za-z][A-Za-z0-9:_-]*>\s*$/ ? 1 : 0;
}

sub _attrib_is_inline_style_closing_only_line ( $line ) {
  return $line =~ /^\s*">\s*$/ ? 1 : 0;
}

sub _attrib_is_inline_style_end_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /">\s*$/ || $line =~ /">.*$/;
}

sub _attrib_is_inline_style_start_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*<[A-Za-z][A-Za-z0-9:_-]*\b.*\bstyle="\s*$/ ? 1 : 0;
}

sub _attrib_is_multiline_tag_start_line ( $line ) {
  return 0 unless defined $line;
  return 0 if $line =~ /^\s*<%/;
  return 0 if _attrib_is_inline_style_start_line( $line );
  return $line =~ /^\s*<[^\/!][^>]*$/ ? 1 : 0;
}

sub _attrib_split_html_attributes ( $attr_text ) {
  return () unless defined $attr_text;

  my @attrs;
  pos( $attr_text ) = 0;

  while (
    $attr_text =~ /\G
      \s*
      (
        [A-Za-z_:][-A-Za-z0-9_:.]*
        (?: \s* = \s* (?: " [^"]* " | ' [^']* ' | [^\s"'=<>`]+ ) )?
      )
    /gcx
      )
  {
    push @attrs, $1;
  }

  my $rest = substr( $attr_text, pos( $attr_text ) // 0 );
  return () if $rest =~ /\S/;

  return @attrs;
}

sub _attrib_split_inline_style_tail ( $line ) {
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

sub _attrib_split_style_declarations ( $style ) {
  return () unless defined $style && length $style;

  my @parts = split /;/, $style;
  @parts = map {
    my $x = $_;
    $x =~ s/^\s+//;
    $x =~ s/\s+$//;
    $x;
  } @parts;

  @parts = grep { length $_ } @parts;
  @parts = map  { $_ . ';' } @parts;

  return @parts;
}

############################
#
# basic indenting
#
############################

sub _base_apply_basic_indentation ( $self, $text ) {
  $text = '' unless defined $text;

  my @lines = split /\n/, $text, -1;
  my @out;

  my $level                     = 0;
  my $ep_level                  = 0;
  my $step                      = ' ' x $self->{indent_width};
  my $in_comment_block          = 0;
  my $in_script_block           = 0;
  my $in_style_block            = 0;
  my $in_inline_style_block     = 0;
  my $inline_style_base         = 0;
  my $in_multiline_tag_open     = 0;
  my $style_inner_level         = 0;
  my $multiline_tag_base        = 0;
  my $multiline_tag_opens       = 0;
  my $multiline_tag_attr_levels = 1;
  my @inline_style_lines;

  for my $line ( @lines ) {
    my $trimmed = $line;
    $trimmed =~ s/^\s+//;
    $trimmed =~ s/\s+$//;

    if ( $in_inline_style_block ) {
      push @inline_style_lines, $line;

      if ( _attrib_is_inline_style_end_line( $trimmed ) ) {
        my $tail_has_closing_tag =
            _attrib_inline_style_tail_has_closing_tag( $trimmed );

        push @out,
            $self->_attrib_format_inline_style_block( \@inline_style_lines,
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
      push @out,
          ( $step x ( $multiline_tag_base + $multiline_tag_attr_levels ) )
          . $trimmed;

      if ( _base_is_tag_end_line( $trimmed ) ) {
        $level++ if $multiline_tag_opens && $trimmed !~ /\/>\s*$/;
        $in_multiline_tag_open     = 0;
        $multiline_tag_opens       = 0;
        $multiline_tag_attr_levels = 1;
      }

      next;
    }

    if ( _attrib_is_inline_style_start_line( $trimmed ) ) {
      my $tag = _attrib_inline_style_tag_name( $trimmed );

      $in_inline_style_block = 1;
      $inline_style_base     = $level + $ep_level;
      @inline_style_lines    = ( $line );

      if ( defined $tag
           && !_base_is_void_html_or_self_closing_tag( $tag, $trimmed ) )
      {
        $level++;
      }

      next;
    }

    if ( _base_is_html_line_with_ep( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      next;
    }

    if ( _base_line_contains_ep( $line ) ) {
      $ep_level-- if _base_ep_closes_before( $line ) && $ep_level > 0;

      if ( _base_is_ep_control_line( $line ) ) {
        my $ep_line = _base_normalize_percent_line( $trimmed );
        push @out, ( $step x $level ) . $ep_line;
      }
      elsif ( $line =~ /^\s*%/ ) {
        my $ep_line       = _base_normalize_percent_line( $trimmed );
        my $content_depth = $level + _base_effective_ep_indent( $ep_level );
        push @out, ( $step x $content_depth ) . $ep_line;
      }
      else {
        push @out,
            ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
            . $trimmed;
      }

      $ep_level++ if _base_ep_opens_after( $line );
      next;
    }

    if ( _attrib_is_multiline_tag_start_line( $trimmed ) ) {
      my ( $tag ) = $trimmed =~ /^\s*<([A-Za-z][A-Za-z0-9:_-]*)\b/;

      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;

      $in_multiline_tag_open = 1;
      $multiline_tag_base    = $level + _base_effective_ep_indent( $ep_level );
      $multiline_tag_opens =
          ( defined $tag
            && !_base_is_void_html_or_self_closing_tag( $tag, $trimmed ) )
          ? 1
          : 0;

      $multiline_tag_attr_levels = $self->{attributes} ? 2 : 1;

      next;
    }

    if ( $in_comment_block ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      $in_comment_block = 0 if _base_is_html_comment_end_line( $trimmed );
      next;
    }

    if ( $in_script_block ) {
      my $base = $level + _base_effective_ep_indent( $ep_level );

      if ( _base_is_script_end_line( $trimmed ) ) {
        push @out, ( $step x $base ) . $trimmed;
        $in_script_block = 0;
      }
      else {
        push @out, ( $step x ( $base + 1 ) ) . $trimmed;
      }

      next;
    }

    if ( $in_style_block ) {
      my $base = $level + _base_effective_ep_indent( $ep_level );

      if ( _base_is_style_end_line( $trimmed ) ) {
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

    if ( _base_is_html_comment_start_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      $in_comment_block = 1 unless _base_is_html_comment_line( $trimmed );
      next;
    }

    if ( _attrib_is_multiline_tag_start_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;

      $in_multiline_tag_open = 1;
      $multiline_tag_base    = $level + _base_effective_ep_indent( $ep_level );

      next;
    }

    if ( _base_is_script_start_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      $in_script_block = 1 unless _base_is_script_end_line( $trimmed );
      next;
    }

    if ( _base_is_style_start_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      $in_style_block    = 1 unless _base_is_style_end_line( $trimmed );
      $style_inner_level = 0;
      next;
    }

    if ( _base_is_doctype_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      next;
    }

    if ( _base_is_html_comment_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      next;
    }

    if ( _base_is_mixed_inline_html_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      next;
    }

    if ( _base_is_html_root_close_line( $trimmed ) ) {
      push @out, ( $step x _base_effective_ep_indent( $ep_level ) ) . $trimmed;
      next;
    }

    if ( _base_is_html_root_open_line( $trimmed ) ) {
      push @out, ( $step x _base_effective_ep_indent( $ep_level ) ) . $trimmed;
      next;
    }

    if ( _base_is_pure_closing_tag_line( $trimmed ) ) {
      $level-- if $level > 0;
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      next;
    }

    if ( _base_is_pure_opening_tag_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      $level++;
      next;
    }

    if ( _base_is_pure_void_tag_line( $trimmed ) ) {
      push @out,
          ( $step x ( $level + _base_effective_ep_indent( $ep_level ) ) )
          . $trimmed;
      next;
    }

    if ( _base_is_plain_text_line( $trimmed ) ) {
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

sub _base_cohere_mixed_ep_micro_blocks ( $self, $text ) {
  my @lines = split /\n/, $text, -1;
  my @out;
  my $i = 0;

  while ( $i <= $#lines ) {
    my $line = $lines[$i];

    unless (    _base_is_percent_line( $line )
             || _base_is_ep_output_line( $line ) )
    {
      push @out, $line;
      $i++;
      next;
    }

    my @block;

    while ( $i <= $#lines ) {
      my $cur = $lines[$i];
      last
          unless _base_is_percent_line( $cur )
          || _base_is_ep_output_line( $cur );
      push @block, $cur;
      $i++;
    }

    my $has_controlish = grep { _base_is_percent_controlish_line( $_ ) } @block;
    my $has_ep_output  = grep { _base_is_ep_output_line( $_ ) } @block;
    my $has_closer     = grep { _base_is_percent_closer_line( $_ ) } @block;

    if ( $has_controlish && $has_ep_output && $has_closer ) {
      my $target;
      for my $l ( @block ) {
        next unless _base_is_percent_line( $l );
        $target = _base_percent_indent( $l );
        last;
      }
      $target //= 0;

      for my $l ( @block ) {
        if ( _base_is_percent_line( $l ) ) {
          $l =~ s/^\s*(%.*)$/' ' x $target . $1/e;
          push @out, $l;
        }
        elsif ( _base_is_ep_output_line( $l ) ) {
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

sub _base_cohere_percent_clusters ( $self, $text ) {
  my @lines = split /\n/, $text, -1;
  my @out;
  my $i = 0;

  while ( $i <= $#lines ) {
    if ( !_base_is_percent_line( $lines[$i] ) ) {
      push @out, $lines[ $i++ ];
      next;
    }

    my @cluster;

    while ( $i <= $#lines && _base_is_percent_line( $lines[$i] ) ) {
      push @cluster, $lines[$i];
      $i++;
    }

    my $has_controlish =
        grep { _base_is_percent_controlish_line( $_ ) } @cluster;
    my $has_closer = grep { _base_is_percent_closer_line( $_ ) } @cluster;
    my $starts_with_sub =
        @cluster && _base_is_percent_sub_opener_line( $cluster[0] );

    if ( $has_controlish && $has_closer && !$starts_with_sub ) {
      my $target;
      for my $l ( @cluster ) {
        next unless _base_is_percent_line( $l );
        my $n = _base_percent_indent( $l );
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

sub _base_effective_ep_indent ( $ep_level ) {
  return $ep_level > 0 ? 1 : 0;
}

sub _base_ensure_final_newline ( $self, $text ) {
  $text = '' unless defined $text;

  $text =~ s/\n*\z/\n/;

  return $text;
}

sub _base_ep_closes_before ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%\s*}/ ? 1 : 0;
}

sub _base_ep_opens_after ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%.*\{\s*$/ ? 1 : 0;
}

sub _base_is_doctype_line ( $line ) {
  return $line =~ /^\s*<!DOCTYPE\b/i ? 1 : 0;
}

sub _base_is_ep_control_line ( $line ) {
  return 0 unless defined $line;
  return 0 unless $line =~ /^\s*%/;

  return 1 if $line =~ /^\s*%\s*}/;
  return 1 if $line =~ /^\s*%\s*(?:if|elsif|else|for|foreach|while|unless)\b/;

  return 0;
}

sub _base_is_ep_output_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*<%=[\s\S]*%>\s*$/ ? 1 : 0;
}

sub _base_is_html_comment_end_line ( $line ) {
  return $line =~ /-->\s*$/ ? 1 : 0;
}

sub _base_is_html_comment_line ( $line ) {
  return $line =~ /^\s*<!--.*-->\s*$/ ? 1 : 0;
}

sub _base_is_html_comment_start_line ( $line ) {
  return $line =~ /^\s*<!--/ ? 1 : 0;
}

sub _base_is_html_line_with_ep ( $line ) {
  return 0 if !defined $line || $line eq '';
  return 0 unless $line =~ /^\s*</;
  return 0 if $line     =~ /^\s*<%[=%#]?/; # leading EP tag line stays untouched
  return 0 unless _base_line_contains_ep( $line );
  return 1;
}

sub _base_is_html_root_close_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*<\/html>\s*$/i ? 1 : 0;
}

sub _base_is_html_root_open_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*<html>\s*$/i ? 1 : 0;
}

sub _base_is_mixed_inline_html_line ( $line ) {
  return 0 if !defined $line || $line eq '';
  return 0 if _base_line_contains_ep( $line );

  return 0 if _base_is_pure_opening_tag_line( $line );
  return 0 if _base_is_pure_closing_tag_line( $line );
  return 0 if _base_is_pure_void_tag_line( $line );
  return 0 if _base_is_doctype_line( $line );
  return 0 if _base_is_html_comment_line( $line );

  return 1 if $line =~ /</ && $line =~ />/;

  return 0;
}

sub _base_is_percent_closer_line ( $line ) {
  return defined $line && $line =~ /^\s*%\s*}/ ? 1 : 0;
}

sub _base_is_percent_comment_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%\s*#/ ? 1 : 0;
}

sub _base_is_percent_controlish_line ( $line ) {
  return 0 unless defined $line;
  return 1 if $line =~ /^\s*%\s*#/;
  return 1 if $line =~ /^\s*%\s*(?:if|elsif|else|for|foreach|while|unless)\b/;
  return 1 if $line =~ /^\s*%\s*}/;
  return 0;
}

sub _base_is_percent_line ( $line ) {
  return defined $line && $line =~ /^\s*%/ ? 1 : 0;
}

sub _base_is_percent_sub_opener_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ /^\s*%\s*.*\bsub\s*\{\s*$/ ? 1 : 0;
}

sub _base_is_plain_text_line ( $line ) {
  return 0 if !defined $line || $line eq '';
  return 0 if _base_line_contains_ep( $line );
  return 0 if $line =~ /</;
  return 1;
}

sub _base_is_pure_closing_tag_line ( $line ) {
  return $line =~ m{^</[A-Za-z][A-Za-z0-9:_-]*>\s*$} ? 1 : 0;
}

sub _base_is_pure_opening_tag_line ( $line ) {
  return 0 if $line =~ /<%/;
  return 0 if $line =~ m{^</};

  return $line =~ m{^<([A-Za-z][A-Za-z0-9:_-]*)(?:\s+[^<>]*)?>\s*$}
      ? !_base_is_void_html_tag( $1 )
      : 0;
}

sub _base_is_pure_void_tag_line ( $line ) {
  return 0 if $line =~ /<%/;

  return $line =~ m{^<([A-Za-z][A-Za-z0-9:_-]*)(?:\s+[^<>]*)?/?>\s*$}
      ? _base_is_void_html_tag( $1 ) || $line =~ m{/>$}
      : 0;
}

sub _base_is_script_end_line ( $line ) {
  return $line =~ /^\s*<\/script>\s*$/i ? 1 : 0;
}

sub _base_is_script_start_line ( $line ) {
  return $line =~ /^\s*<script\b[^>]*>\s*$/i ? 1 : 0;
}

sub _base_is_style_end_line ( $line ) {
  return $line =~ /^\s*<\/style>\s*$/i ? 1 : 0;
}

sub _base_is_style_start_line ( $line ) {
  return $line =~ /^\s*<style\b[^>]*>\s*$/i ? 1 : 0;
}

sub _base_is_tag_end_line ( $line ) {
  return 0 unless defined $line;
  return $line =~ />\s*$/ ? 1 : 0;
}

sub _base_is_void_html_or_self_closing_tag ( $tag, $line ) {
  return 1 if defined $line && $line =~ /\/>\s*$/;
  return _base_is_void_html_tag( $tag );
}

sub _base_is_void_html_tag ( $tag ) {
  state %void = map { $_ => 1 } qw(
      area base br col embed hr img input link meta param source track wbr
  );

  return $void{lc $tag} ? 1 : 0;
}

sub _base_line_contains_ep ( $line ) {
  return $line =~ /<%|^\s*%/ ? 1 : 0;
}

sub _base_line_indent ( $line ) {
  return 0 unless defined $line;
  $line =~ /^(\s*)/;
  return length( $1 // '' );
}

sub _base_normalize_line_endings ( $self, $text ) {
  $text = '' unless defined $text;

  $text =~ s/\r\n/\n/g;
  $text =~ s/\r/\n/g;

  return $text;
}

sub _base_normalize_percent_line ( $line ) {
  return $line unless defined $line;
  $line =~ s/^\s*%\s*/% /;
  return $line;
}

sub _base_percent_indent ( $line ) {
  return 0 unless defined $line;
  $line =~ /^(\s*)%/;
  return defined $1 ? length( $1 ) : 0;
}

sub _base_strip_trailing_whitespace ( $self, $text ) {
  $text = '' unless defined $text;

  $text =~ s/[ \t]+$//mg;

  return $text;
}

############################
#
# --columns operations
#
############################

sub _cols_apply_column_expansion ( $self, $text ) {
  my @lines = split /\n/, $text, -1;
  my @out;

  for my $line ( @lines ) {
    unless ( $self->_cols_line_exceeds_columns( $line ) ) {
      push @out, $line;
      next;
    }

    my $expanded = $self->_cols_expand_long_inline_style_tag( $line )
        // $self->_cols_expand_long_simple_nested_tag_line( $line )
        // $self->_cols_expand_long_generic_opening_tag( $line )
        // $self->_cols_expand_long_comment_line( $line );

    if ( defined $expanded ) {
      push @out, split /\n/, $expanded, -1;
    }
    else {
      push @out, $line;
    }
  }

  return join "\n", @out;
}

sub _cols_comment_split_candidates ( $body ) {
  return () unless defined $body && length $body;

  my @cand;
  my $len = length $body;

  for my $i ( 0 .. $len - 1 ) {
    my $ch = substr( $body, $i, 1 );

    if ( $ch =~ /[;,.!?]/ ) {
      push @cand, $i;
      next;
    }

    if ( $ch eq '/' || $ch eq '\\' ) {
      my $prev = $i > 0        ? substr( $body, $i - 1, 1 ) : ' ';
      my $next = $i < $len - 1 ? substr( $body, $i + 1, 1 ) : ' ';

      next if $prev !~ /\s/;
      next if $next !~ /\s/;

      push @cand, $i;
      next;
    }
  }

  return @cand;
}

sub _cols_expand_long_comment_line ( $self, $line ) {
  return undef unless defined $line;
  return undef unless $self->_cols_line_exceeds_columns( $line );

  my ( $indent ) = $line =~ /^(\s*)/;
  $indent //= '';

  my $trimmed = $line;
  $trimmed =~ s/^\s+//;
  $trimmed =~ s/\s+$//;

  return undef unless $trimmed =~ /^<!--\s*(.*?)\s*-->$/;
  my $body = $1;
  $body =~ s/^\s+//;
  $body =~ s/\s+$//;

  return undef unless length $body;
  return undef if $body =~ /\n/;

  my $available = $self->{columns} - length( $indent ) - length( '<!--  -->' );
  return undef if $available < 8;

  # pass 1: punctuation-aware split
  my @parts = $self->_cols_split_long_comment_body( $body, $available );

  # pass 2: fallback to word-boundary wrapping into repeated comment lines
  if ( @parts <= 1 && length( $body ) > $available ) {
    @parts = $self->_cols_wrap_comment_body_words( $body, $available );
  }

  return undef unless @parts > 1;

  my @out = map { $indent . '<!-- ' . $_ . ' -->' } @parts;
  return join "\n", @out;
}

sub _cols_expand_long_generic_opening_tag ( $self, $line ) {
  return undef unless defined $line;
  return undef unless $self->_cols_line_exceeds_columns( $line );

  my ( $indent ) = $line =~ /^(\s*)/;
  $indent //= '';

  my $trimmed = $line;
  $trimmed =~ s/^\s+//;
  $trimmed =~ s/\s+$//;

  # only pure one-line opening tags,
  # not closers, comments, doctype, or self-closing
  return undef unless $trimmed =~ /^<([A-Za-z][A-Za-z0-9:_-]*)\b(.*)>$/;
  my ( $tag, $attrs ) = ( $1, $2 );

  return undef if $trimmed =~ m{^</};
  return undef if $trimmed =~ /^<!/;
  return undef if $trimmed =~ /\/>\s*$/;

  # let preferred-element and style-specific logic own their cases
  return undef if $tag   =~ /\A(?:form|input|button|a)\z/i;
  return undef if $attrs =~ /\bstyle="/;

  my @attrs = _attrib_split_html_attributes( $attrs );
  return undef unless @attrs >= 2;

  my $step      = ' ' x $self->{indent_width};
  my $attr_step = $step . $step;

  my @out;
  my $first = shift @attrs;

  push @out, $indent . "<$tag " . $first;

  while ( @attrs > 1 ) {
    push @out, $indent . $attr_step . shift @attrs;
  }

  push @out, $indent . $attr_step . $attrs[0] . '>';

  return join "\n", @out;
}

sub _cols_expand_long_inline_style_tag ( $self, $line ) {
  return undef unless defined $line;
  return undef unless $self->_cols_line_exceeds_columns( $line );

  my ( $indent ) = $line =~ /^(\s*)/;
  $indent //= '';

  my $trimmed = $line;
  $trimmed =~ s/^\s+//;
  $trimmed =~ s/\s+$//;

  return undef unless $trimmed =~ /^<([A-Za-z][A-Za-z0-9:_-]*)\b/;
  return undef unless $trimmed =~ /^(.*?\bstyle=")([^"]+)(".*)$/;

  my ( $before, $style, $after ) = ( $1, $2, $3 );

  return undef if $style =~ /<[%=]?/;

  my @decls = _attrib_split_style_declarations( $style );
  return undef unless @decls >= 2;

  my @out;
  push @out, $indent . $before;
  push @out, map { $indent . $_ } @decls;
  $out[-1] .= $after;

  return join "\n", @out;
}

sub _cols_expand_long_simple_nested_tag_line ( $self, $line ) {
  return undef unless defined $line;
  return undef unless $self->_cols_line_exceeds_columns( $line );

  my $trimmed = $line;
  $trimmed =~ s/^\s+//;
  $trimmed =~ s/\s+$//;

  return undef if $trimmed =~ /^</ ? 0 : 1;
  return undef if $trimmed =~ /<!--|<!DOCTYPE/i;

  # very narrow pattern:
  # <outer><inner>content</inner></outer>
  return undef unless $trimmed =~

m{^<([A-Za-z][A-Za-z0-9:_-]*)>(<([A-Za-z][A-Za-z0-9:_-]*)>)(.*?)(</\3>)(</\1>)$};

  my ( $outer, $inner_open, $inner, $content, $inner_close, $outer_close ) =
      ( $1, $2, $3, $4, $5, $6 );

  return undef unless length $content;

  # no nested real html inside content
  return undef if $content =~ /<(?![%=])/;
  return undef if $content =~ /^\s*$/;

  return join "\n",
      "<$outer>",
      "  $inner_open",
      "    $content",
      "  $inner_close",
      $outer_close;
}

sub _cols_line_exceeds_columns ( $self, $line ) {
  return 0 unless defined $self->{columns} && $self->{columns};
  return length( $line ) > $self->{columns} ? 1 : 0;
}

sub _cols_split_long_comment_body ( $self, $body, $available ) {
  return ( $body ) unless defined $body      && length $body;
  return ( $body ) unless defined $available && $available > 0;

  my @parts;
  my $rest = $body;

  while ( length( $rest ) > $available ) {
    my @cand = _cols_comment_split_candidates( $rest );
    @cand = grep { $_ < $available } @cand;

    last unless @cand;

    my $split_at = $cand[-1];
    my $left     = substr( $rest, 0, $split_at + 1 );
    my $right    = substr( $rest, $split_at + 1 );

    $left  =~ s/\s+$//;
    $right =~ s/^\s+//;

    last unless length $left;
    push @parts, $left;
    $rest = $right;
  }

  push @parts, $rest if length $rest;
  return @parts;
}

sub _cols_wrap_comment_body_words ( $self, $body, $available ) {
  return ( $body ) unless defined $body      && length $body;
  return ( $body ) unless defined $available && $available > 0;

  my @words = grep { length $_ } split /\s+/, $body;
  return ( $body ) unless @words;

  my @parts;
  my $line = shift @words;

  for my $word ( @words ) {
    my $try = $line . ' ' . $word;

    if ( length( $try ) <= $available ) {
      $line = $try;
    }
    else {
      push @parts, $line;
      $line = $word;
    }
  }

  push @parts, $line if length $line;
  return @parts;
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
