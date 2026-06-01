package Mojo::PrettyTidy;

use v5.40.0;
use feature 'signatures';

use common::sense;
use Cwd;
use File::Path qw/make_path/;
use File::Basename;
use File::Spec;
use JavaScript::Beautifier qw/js_beautify/;

our $VERSION = '0.01';

sub new ( $class, %args ) {
  my $self = bless {
          indent_width => defined $args{indent_width} ? $args{indent_width} : 2,
          tab_width    => defined $args{tab_width}    ? $args{tab_width}    : 2,
          columns      => defined $args{columns}      ? $args{columns}      : 0,
          attributes   => defined $args{attributes}   ? $args{attributes}   : 1,
          javascript   => defined $args{javascript}   ? $args{javascript}   : 1,
          maxchars     => defined $args{maxchars}     ? $args{maxchars}     : 0,
          sourceview   => defined $args{sourceview}   ? $args{sourceview}   : 0,
  }, $class;

  return $self;
}

sub _chunk ( $self, $text ) {
  my @chunks;

  $text = $self->_ep_early_breakpoints( $text );

  for my $line ( split /\n/, $text, -1 ) {
    if ( $line =~ /^\s*$/ ) {
      push @chunks, {kind => 'blank', text => ''};
      next;
    }

    if ( $line =~ /^\s*<script\b/i || $line =~ /^\s*<\/script>/i ) {
      push @chunks, {kind => 'script', text => $line};
      next;
    }

    my $ep = $self->_ep_control( $line );

    if ( defined $ep ) {
      push @chunks, {kind => 'ep_control', text => $line, ep => $ep};
      next;
    }

    push @chunks, {kind => 'html', text => $line};
  }

  return @chunks;
}

sub _ep_early_breakpoints ( $self, $text ) {
  return '' unless defined $text && length $text;

  # HTML comments are their own visible units. Multi-line comment bodies are
  # otherwise left alone.
  $text =~ s{\n*(<!--)}{\n$1}g;
  $text =~ s{(-->)\n*}{$1\n}g;

  # Split common block-ish tags that flattening glued together.
  $text =~ s{>[
\t]*(?=<(?:html|head|body|title|meta|link|script|style|div|form|label|input|option|
button|table|thead|tbody|tr|td|th|ul|ol|li|section|article)\b)}{>\n}gi;
  $text =~ s{(>)[\t]*(?=%\s*
(?:if|elsif|else|unless|for|foreach|while|my|our|state|return|end)\b)}{$1\n}g;
  $text =~ s{(</script>)[ \t]*(?=<)}{$1\n}gi;
  $text =~ s{(</style>)[ \t]*(?=<)}{$1\n}gi;

  # Closing tag glued to another tag or EP marker.
  $text =~ s{(</[A-Za-z][A-Za-z0-9:_-]*>)[ \t]*(?=<|%)}{$1\n}g;

  # Keep a closing table cell with the preceding inline close for now.
  $text =~ s{(</[A-Za-z][A-Za-z0-9:_-]*>)\n(</td>)}{$1$2}g;

  # EP statement immediately followed by another EP line.
  $text =~ s/\;%/;\n%/g;

  # EP comment glued to another EP line.
  $text =~ s{(%\s*\#[^\n]*?)(?=%\s*)}{$1\n}gx;

  # EP opener/transition glued to preceding payload.
  $text =~ s{(?<!\n)(?=%\s*(?:if|unless|for|foreach|while)\b)}{\n}g;

  # EP opener/transition glued to trailing payload.
  $text =~
s{(%\s*(?:\}\s*)?(?:if|elsif|else|unless|for|foreach|while)\b[^\n]*?(?<!@)\{)(?=\S)}
{$1\n}gx;

  # EP begin glued to trailing template payload.
  $text =~ s{ (%[=\s][^\n]*?\bbegin) (?=<[A-Za-z]) }{$1\n}gx;

  # closing end when glued to HTML
  $text =~ s{(?<!\n)(?=%\s*end\b)}{\n}g;
  $text =~ s{(%\s*end\b)(?=<[A-Za-z])}{$1\n}g;

  # EP closer glued to trailing payload. This intentionally catches both tags
  # and text payload such as `% }&nbsp; ...` so the closer remains classifiable.
  $text =~ s{(%\s*\})(?=\S)}{$1\n}gx;

  # Before EP expression-output lines:
  #   $text =~ s{(?<!\n)(?=%=)}{\n}gx;
  $text =~ s{ (?<![\n<]) (?=%=) }{\n}gx;

  # Before EP control/statement lines.

  $text =~ s{
    (?<!\n)
    (?=%\s*(?:if|elsif|else|unless|for|foreach|while|my|our|state|return)\b)
  }{\n}gx;

  # Before standalone EP comments only. Do not touch inline trailing # comments.
  $text =~ s{(?<!\n)(?=%\s*\#\s)}{\n}g;

  # Before EP close/transition lines.
  $text =~ s/(?<!\n)(?=%\s*\})/\n/g;

  # EP statement/comment glued to an opening HTML tag.
  $text =~ s{(^%\s*[^\n]*?;)(?=<!?[A-Za-z])}{$1\n}gmx;
  $text =~ s{(%\s*(?:my|our|state|return)\b[^\n]*?;)(?=<[A-Za-z])}{$1\n\n}gx;
  $text =~ s{(%\s*\#[^\n]*?;)(?=<[A-Za-z])}{$1\n\n}gx;

  $text = $self->_js_prebake_scripts( $text );

  #   $text = $self->_normalize_ep_multiline_deref_blocks( $text );

  return $text;
}

sub _ep_control ( $self, $line ) {
  return undef unless defined $line && length $line;

  my $x = $line;
  $x =~ s/^\s+//;
  $x =~ s/\s+$//;

  my $is_output_begin = $x =~ /^%=\s+.*\bbegin\s*\z/;

  return undef if $x =~ /^%=/ && !$is_output_begin;

  if ( $is_output_begin ) {
    $x =~ s/^%=\s+// or return undef;
  } else {
    $x =~ s/^%\s+// or return undef;
  }

  return 'comment' if $x =~ /\A#/;
  return 'closer'  if $x =~ /\A}\s*\z/;

  return 'transition' if $x =~ /\A}\s*(?:else|elsif)\b.*\{\s*\z/;
  return 'transition' if $x =~ /\A(?:else|elsif)\b.*\{\s*\z/;

  return 'opener'
      if $x =~ /\A(?:if|for|foreach|while|unless)\b.*\{\s*\z/
      && $x !~ /\@\{\s*\z/;

  #   return 'opener' if $x =~ /\A[^\n]*\}\)\s*\{\s*\z/;

  return 'begin'     if $x =~ /\bbegin\s*\z/;
  return 'end'       if $x =~ /\Aend\b\s*\z/;
  return 'statement' if $x =~ /;\s*(?:#.*)?\z/;

  # Fallback: a full-line EP marker is still Perl code, even when it is
  # a continuation like:
  #   % for my $line (@{
  #   % }) {
  return 'statement';
}

sub _ep_postfix_indentation ( $self, $text ) {
  return '' unless defined $text && length $text;

  # EP control-block payload indentation.
  #
  # Handles:
  #   % if (...) {
  #       <payload>
  #   % }
  #
  # Non-% payload lines inside EP control blocks get one extra visual indent.
  # % lines keep their perltidy-derived indentation.
  my @out;
  my $level     = 0;
  my $in_script = 0;
  my $indent    = ' ' x $self->{indent_width};

  for my $line ( split /\n/, $text, -1 ) {
    my $kind = $self->_ep_control( $line );

    if ( defined $kind && ( $kind eq 'closer' || $kind eq 'transition' ) ) {
      $level-- if $level > 0;
    }

    my $target         = $level > 0 ? $indent x $level         : '';
    my $payload_target = $level > 0 ? $indent x ( $level + 1 ) : '';

    if ( $line =~ /^\s*<script\b/i ) {
      if ( length $target ) {
        $line =~ s/^\s*/$target/;
      }

      $in_script = 1;
      push @out, $line;
      next;
    }

    if ( $in_script ) {
      if ( $line =~ m{^\s*</script>}i ) {
        if ( length $target ) {
          $line =~ s/^\s*/$target/;
        }

        $in_script = 0;
        push @out, $line;
        next;
      }

      if ( length $line ) {
        $line = $target . $indent . $line;
      }

      push @out, $line;
      next;
    }

    # EP/code lines keep their own perltidy-derived indentation.
    # Do not apply payload indentation to them.
    if ( $line =~ /^\s*%/ ) {
      push @out, $line;

      if ( defined $kind && ( $kind eq 'opener' || $kind eq 'transition' ) ) {
        $level++;
      }

      next;
    }

    # Non-EP payload lines inside EP blocks get one extra visual indent.
    if ( $level > 0 && length $line ) {
      my $leading = '';

      if ( $line =~ /^(\s*)/ ) {
        $leading = $1;
      }

      if ( length( $leading ) < length( $payload_target ) ) {
        $line =~ s/^\s*/$payload_target/;
      }
    }

    push @out, $line;

    if ( defined $kind && ( $kind eq 'opener' || $kind eq 'transition' ) ) {
      $level++;
    }
  }

  $text = join "\n", @out;

  # Mojo begin/end helper indentation.
  #
  # Handles:
  #   % my $cb = begin
  #       <payload>
  #   % end
  #
  # existing _reemit_begin_blocks body here
  my @out;
  my $level  = 0;
  my $indent = ' ' x $self->{indent_width};

  for my $line ( split /\n/, $text, -1 ) {
    my $kind = $self->_ep_control( $line );

    if ( defined $kind && $kind eq 'end' ) {
      $level-- if $level > 0;
    }

    if ( $level > 0 && length $line ) {
      my $target  = $indent x $level;
      my $leading = '';

      if ( $line =~ /^(\s*)/ ) {
        $leading = $1;
      }

      if ( length( $leading ) < length( $target ) ) {
        $line =~ s/^\s*/$target/;
      }
    }

    push @out, $line;

    if ( defined $kind && $kind eq 'begin' ) {
      $level++;
    }
  }

  return join "\n", @out;
}

sub ep_source_file ( $self, $file ) {
  $self->{ep_source_file} = $file if defined $file && length $file;
  return $self;
}

sub _flatten ( $self, $text ) {
  return '' unless defined $text && length $text;

  $text =~ s/\r\n?/\n/g;

  my @lines = split /\n/, $text;

  for my $line ( @lines ) {
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
  }

  return join '', grep {length} @lines;
}

sub _html_separate_blocks ( $self, $text ) {
  return '' unless defined $text && length $text;

  my $block =
      qr/(?:div|section|article|table|thead|tbody|tfoot|tr|td|th|ul|ol|p)/;

  $text =~ s{(<$block\b[^>]*>)[ \t]*(?=<$block\b)}{$1\n}gi;
  $text =~ s{(</$block>)[ \t]*(?=<$block\b)}{$1\n}gi;
  $text =~ s{(</$block>)[ \t]*(?=</$block>)}{$1\n}gi;

  # Lists get a visual block break before them.
  $text =~ s{(</$block>)[ \t]*\n?(<(?:ul|ol)\b[^>]*>)}{$1\n\n$2}gi;

  # List items: break before each <li>, and after each </li>.
  $text =~ s{(<(?:ul|ol)\b[^>]*>)[ \t]*(?=<li\b)}{$1\n}gi;
  $text =~ s{(</li>)[ \t]*(?=<li\b)}{$1\n}gi;
  $text =~ s{(</li>)[ \t]*(?=</(?:ul|ol)>)}{$1\n}gi;

  # List items: put primary child anchors/divs on their own lines.
  $text =~ s{(<li\b[^>]*>)[ \t]*(?=<(?:a|div)\b)}{$1\n}gi;

  # Dropdown/menu anchors: one item per line.
  $text =~ s{(<div\b[^>]*\bdropdown-menu\b[^>]*>)[ \t]*(?=<a\b)}{$1\n}gi;
  $text =~ s{(</a>)[ \t]*(?=<a\b)}{$1\n}gi;
  $text =~ s{(</a>)[ \t]*(?=<div\b[^>]*\bdropdown-divider\b)}{$1\n}gi;
  $text =~ s{(</div>)[ \t]*(?=<a\b)}{$1\n}gi;

  # Close list-item internals cleanly.
  $text =~ s{(</a>)[ \t]*(?=</li>)}{$1\n}gi;
  $text =~ s{(</div>)[ \t]*(?=</li>)}{$1\n}gi;

  return $text;
}

sub _html_separate_landmarks ( $self, $text ) {
  return '' unless defined $text && length $text;

  # Top-level document landmarks.
  $text =~ s{(<html\b[^>]*>)\n(<head\b[^>]*>)}{$1\n\n$2}gi;
  $text =~ s{(</head>)\n(<body\b[^>]*>)}{$1\n\n$2}gi;

  # Body/header/nav opening sequence.
  $text =~ s{(<body\b[^>]*>)\n?(<header\b[^>]*>)}{$1\n$2}gi;
  $text =~ s{(<header\b[^>]*>)\n?(<nav\b[^>]*\bnavbar\b[^>]*>)}{$1\n$2\n}gi;

  # Brand/link block inside navbar.
  $text =~
s{(<nav\b[^>]*\bnavbar\b[^>]*>)\n?(<a\b[^>]*\bnavbar-brand\b[^>]*>)}{$1\n\n$2}gi;

  # Main content landmark.
  $text =~ s{(<div\b[^>]*>)\n(<main\b[^>]*>)}{$1\n\n$2}gi;

  # Footer landmark.
  $text =~ s{(</div>)\n(</div>)\n(<footer\b[^>]*>)}{$1\n$2\n\n$3}gi;

  return $text;
}

sub _js_prebake_scripts ( $self, $text ) {
  return '' unless defined $text && length $text;

  # Basic boundary cleanup before extraction.
  $text =~ s{\n*(?=<script\b)}{\n\n}gi;
  $text =~ s{(<script\b[^>]*>)\s*(?=\S)}{$1\n}gi;
  $text =~ s{([^\n])(?=</script>)}{$1\n}gi;
  $text =~ s{(</script>)\n*}{$1\n\n}gi;

  my $out     = '';
  my $pos     = 0;
  my $matched = 0;

  while ( $text =~ m{(<script\b(?![^>]*\bsrc\s*=)[^>]*>)(.*?)(</script>)}gis ) {
    $matched++;

    my $match_start = $-[0];
    my $match_end   = $+[0];

    my ( $open, $body, $close ) = ( $1, $2, $3 );

    $out .= substr( $text, $pos, $match_start - $pos );

    $body =~ s/\A\s+//;
    $body =~ s/\s+\z//;

    my $original_body = $body;

    $body = $self->_js_format_text( $body, $matched );

    my $note = '';
    if ( $body ne $original_body ) {
      $note = "\n"
          . "<!--\n"
          . "This block has been reformatted from the original.\n"
          . "If the JavaScript no longer runs,\n"
          . "rerun with --javascript=off.\n"
          . "-->\n\n";
    }

    $out .= "$open\n$note$body\n$close";

    $pos = $match_end;
  }

  $out .= substr( $text, $pos );

  if ( $matched ) {
    $text = $out;
  }

  # Re-apply boundary cleanup after reconstruction.
  $text =~ s{\n*(?=<script\b)}{\n\n}gi;
  $text =~ s{(<script\b[^>]*>)\s*(?=\S)}{$1\n}gi;
  $text =~ s{([^\n])(?=</script>)}{$1\n}gi;
  $text =~ s{(</script>)\n*}{$1\n\n}gi;

  return $text;
}

sub _js_format_text ( $self, $js, $matched = undef ) {
  return '' unless defined $js && length $js;

  my $original = $js;

  $js = $self->_js_prebake( $js );

  #   if ( $js =~ /reset UI/ ) {
  #     my $slice = $js;
  #     $slice =~ s/\n/⏎\n/g;
  #
  #   }

  my $formatted = eval {
    js_beautify(
                 $js,
                 {
                  indent_size               => $self->{indent_width},
                  indent_character          => ' ',
                  preserve_newlines         => 1,
                  space_after_anon_function => 0,
                 } );
  };

  if ( $@ ) {
    warn
"JavaScript::Beautifier failed; leaving original JavaScript unchanged: $@";
    return $original;
  }

  return $original unless defined $formatted && length $formatted;

  $formatted = $self->_js_postfix_munges( $js, $formatted );

  if ( $self->_js_formatter_munged( $js, $formatted, $matched ) ) {
    return $original;
  }

  $formatted =~ s/\s+\z//;

  return $formatted;
}

sub _js_formatter_munged ( $self, $before, $after, $matched = undef ) {
  return 0 if !defined $before || !defined $after;
  return 0 if $before eq $after;

  my @problems;

  if ( $before =~ /=>/ && $after =~ /=\s+>/ ) {
    push @problems, 'arrow function token => became = >';
  }

  if ( $before =~ /\?\./ && $after =~ /\?\s+\./ ) {
    push @problems, 'optional chaining token ?. was split';
  }

  if ( $before =~ /\?\?/ && $after =~ /\?\s+\?/ ) {
    push @problems, 'nullish coalescing token ?? was split';
  }

  if ( $before =~ /\?\?=/ && $after =~ /\?\s+\?\s*=/ ) {
    push @problems, 'nullish assignment token ??= was split';
  }

  if ( $before =~ /\|\|=/ && $after =~ /\|\s+\|\s*=/ ) {
    push @problems, 'logical OR assignment token ||= was split';
  }

  if ( $before =~ /&&=/ && $after =~ /&\s+&\s*=/ ) {
    push @problems, 'logical AND assignment token &&= was split';
  }

  if (    $before =~ /\basync[ \t]+function\b/
       && $after =~ /\basync[ \t]*\n[ \t]*function\b/ )
  {
    push @problems, 'async function was split across lines';
  }

  if ( $before =~ m{//[^\n]*\n\s*\S} ) {
    for my $line ( split /\n/, $after ) {
      if (
        $line =~
m{//[^\n]*[A-Za-z0-9_\)](?:document\.|window\.|console\.|const\s+|let\s+|var\s+|if\s
*\(|for\s*\(|while\s*\(|return\b|function\s+|async\s+function\s+|class\s+|new\s+)}
          )
      {
        push @problems, 'line comment may have swallowed following JavaScript';
        last;
      }
    }
  }
  return 0 if !@problems;

  my $where = defined $matched ? " in <script> block $matched" : '';

  warn "PrettyTidy JavaScript formatter may have munged syntax$where;\n"
      . "\tleaving original JavaScript unchanged:\n";

  for my $problem ( @problems ) {
    warn "  - $problem\n";
  }

  return 1;
}

sub _js_prebake ( $self, $js ) {
  return '' unless defined $js && length $js;

# If flattening glued code/comment boundaries together, restore line-comment shape.
  $js =~ s{;\s*(?=//)}{;\n}g;
  $js =~ s{\{\s*(?=//)}{\{\n}g;
  $js =~ s{\}\s*(?=//)}{\}\n}g;

  # If a line comment is glued to the following likely code boundary, split it.
  $js =~ s{
  (//[^\n]*?\S)
  (?=
      document\.
    | window\.
    | console\.
    | const\s+
    | let\s+
    | var\s+
    | if\s*\(
    | for\s*\(
    | while\s*\(
    | switch\s*\(
    | return\b
    | async\s+function\s+
    | function\s+
    | class\s+
    | new\s+
    | await\s+
    | \}\s*else\b
    | \}\s*catch\b
    | \}\s*finally\b
  )
}{$1\n}gx;

  # Flattening can also glue a line comment to a block transition.
  # Example:
  #   // comment} else {
  $js =~ s{
  (//[^\n]*?\S)
  (?=
      \}\s*else\b
    | \}\s*catch\b
    | \}\s*finally\b
  )
}{$1\n}gx;

  # Conservative statement boundaries.
  # Do not split semicolons inside for (...) headers.
  $js =~ s{;\s*(?=(?:const|let|var)\s+)}{;\n}g;
  $js =~ s{;\s*(?=(?:if|for|while|switch|try|catch|finally)\b)}{;\n}g;
  $js =~ s{;\s*(?=(?:async\s+function|function|class)\s+)}{;\n}g;
  $js =~ s{;\s*(?=(?:document|window|console)\.)}{;\n}g;
  $js =~ s{;\s*(?=return\b)}{;\n}g;

  # Function/block boundaries commonly glued by flattening.
  $js =~ s{\}\s*(?=(?:const|let|var)\s+)}{\}\n}g;
  $js =~ s{\}\s*(?=(?:async\s+function|function|class)\s+)}{\}\n}g;
  $js =~ s{\}\s*(?=(?:document|window|console)\.)}{\}\n}g;

  return $js;
}

sub _js_postfix_munges ( $self, $before, $after ) {
  return $after if !defined $before || !defined $after;
  return $after if $before eq $after;

  if ( $before =~ /=>/ ) {
    $after =~ s/=\s+>/=>/g;
    $after =~ s/=>\s*\{/=> {/g;
  }

  if ( $before =~ /\?\?=/ ) {
    $after =~ s/\?\s+\?\s*=/??=/g;
  }

  if ( $before =~ /\?\?/ ) {
    $after =~ s/\?\s+\?/??/g;
  }

  if ( $before =~ /\?\./ ) {
    $after =~ s/\?\s+\./?./g;
  }

  if ( $before =~ /\|\|=/ ) {
    $after =~ s/\|\s+\|\s*=/||=/g;
  }

  if ( $before =~ /&&=/ ) {
    $after =~ s/&\s+&\s*=/&&=/g;
  }

  if ( $before =~ /\basync\s+function\b/ ) {
    $after =~ s/\basync\s*\n\s*function\b/async function/g;
  }

  return $after;
}

sub _pt_debug_cleanup_file ( $self, $name ) {
  return unless defined $name && length $name;

  my $path = File::Spec->catfile( 'tmp', 'perltidy', $name );

  if ( -e $path ) {
    unlink $path or warn "Could not remove $path: $!";
  }

  return;
}

sub _pt_debug_write_file ( $self, $idx, $perl ) {
  my $dir = File::Spec->catdir( 'tmp', 'perltidy' );

  if ( !-d $dir ) { File::Path::make_path( $dir ); }

  my $path = File::Spec->catfile( $dir, sprintf 'pt-region-%03d.pl', $idx );

  open my $fh, '>', $path or die "Cannot write $path: $!";
  print {$fh} $perl;
  close $fh or die "Cannot close $path: $!";

  return $path;
}

sub _pt_prebake_region ( $self, @chunks ) {
  my @out;

  for my $i ( 0 .. $#chunks ) {
    my $chunk = $chunks[$i];
    my $line  = $chunk->{text};

    if ( $chunk->{kind} eq 'blank' ) {
      my $prev = $i > 0        ? $chunks[ $i - 1 ]{text} : '';
      my $next = $i < $#chunks ? $chunks[ $i + 1 ]{text} : '';

      if ( $prev =~ m{</script>\s*\z}i || $next =~ m{\A<script\b}i ) {
        push @out, '0; # PrettyTidy:';
      }

      next;
    }

    if ( $chunk->{kind} eq 'ep_control' ) {
      $line =~ s/^\s*%\s?//;
      push @out, $line;
      next;
    }

    if ( $line =~ /^\s*<script\b/i ) {
      push @out, '0; # PrettyTidy:';
    }

    push @out, '0; # PrettyTidy:' . $line;
  }

  return join "\n", @out;
}

sub _pt_reemit_regions ( $self, @chunks ) {
  my @out;
  my @current;
  my $depth     = 0;
  my $in_region = 0;
  my $idx       = 0;

  for my $pos ( 0 .. $#chunks ) {
    my $chunk = $chunks[$pos];
    my $ep    = $chunk->{kind} eq 'ep_control' ? $chunk->{ep} : undef;

    if ( !$in_region ) {
      if ( defined $ep && $ep eq 'opener' ) {
        $in_region = 1;
        $depth     = 0;
        @current   = ();
      } else {
        my $line = $chunk->{text};

        push @out, '' if $line =~ /^\s*<script\b/i && @out && $out[-1] ne '';
        push @out, $line;
        push @out, '' if $line =~ m{</script>\s*$}i;

        next;
      }
    }

    push @current, $chunk;

    if ( defined $ep && ( $ep eq 'closer' || $ep eq 'transition' ) ) {
      $depth-- if $depth > 0;
    }

    my $next_ep = undef;

    if ( defined $ep && $ep eq 'closer' && $depth == 0 ) {
      for my $j ( ( $pos + 1 ) .. $#chunks ) {
        next if $chunks[$j]{kind} eq 'blank';
        $next_ep = $chunks[$j]{kind} eq 'ep_control' ? $chunks[$j]{ep} : undef;
        last;
      }
    }

    if (    defined $ep
         && $ep eq 'closer'
         && $depth == 0
         && ( $next_ep // '' ) ne 'transition' )
    {
      $idx++;
      my $perl = $self->_pt_prebake_region( @current );

      if (    !defined $perl
           || !length $perl
           || $perl =~ /\@\{\s*(?:\n|\z)/
           || $perl =~ /\bbegin\s*(?:\n|\z)/ )
      {
        for my $chunk ( @current ) {
          my $line = $chunk->{text};
          push @out, '' if $line =~ /^\s*<script\b/i && @out && $out[-1] ne '';
          push @out, $line;
          push @out, '' if $line =~ m{</script>\s*$}i;

        }
      } else {
        my ( $ok, $tidied ) = $self->_pt_run( $perl, $idx );

        if ( !$ok ) {
          for my $chunk ( @current ) {
            my $line = $chunk->{text};
            push @out, ''
                if $line =~ /^\s*<script\b/i && @out && $out[-1] ne '';
            push @out, $line;
            push @out, '' if $line =~ m{</script>\s*$}i;
          }
        } else {
          my $template = $self->_pt_template_from_region( $tidied );
          push @out, split /\n/, $template, -1;
        }
      }

      @current   = ();
      $in_region = 0;
      next;
    }

    if ( defined $ep && ( $ep eq 'opener' || $ep eq 'transition' ) ) {
      $depth++;
    }
  }

  # EOF block
  if ( @current ) {
    $idx++;

    my $perl = $self->_pt_prebake_region( @current );

    if (    !defined $perl
         || !length $perl
         || $perl =~ /\@\{\s*(?:\n|\z)/
         || $perl =~ /\bbegin\s*(?:\n|\z)/ )
    {
      #     if ( !$self->_pt_region_supported( $perl ) ) {
      for my $chunk ( @current ) {
        my $line = $chunk->{text};
        push @out, '' if $line =~ /^\s*<script\b/i && @out && $out[-1] ne '';
        push @out, $line;
        push @out, '' if $line =~ m{</script>\s*$}i;
      }
    } else {
      my ( $ok, $tidied ) = $self->_pt_run( $perl, $idx );

      if ( !$ok ) {
        for my $chunk ( @current ) {
          my $line = $chunk->{text};
          push @out, '' if $line =~ /^\s*<script\b/i && @out && $out[-1] ne '';
          push @out, $line;
          push @out, ''
              if $line =~ m{</script>\s*$}i;
        }
      } else {
        my $template = $self->_pt_template_from_region( $tidied );
        push @out, split /\n/, $template, -1;
      }
    }
  }

  return join "\n", @out;
}

sub _pt_run ( $self, $perl, $idx = 1 ) {

  # try stdin/stdout first
  # if success, return tidied stdout
  # if fail, write debug file and rerun file-mode for .ERR/.LOG
  # return original $perl
  return '' unless defined $perl && length $perl;

  require IPC::Open3;
  require IO::Select;
  require Symbol;

  my @pipe_cmd = ( 'perltidy', '-q', '-st', '-se' );

  my $home_rc = defined $ENV{HOME} ? "$ENV{HOME}/.perltidyrc" : '';

  push @pipe_cmd, "-pro=$home_rc" if length $home_rc && -f $home_rc;

  # PrettyTidy owns wrapping/columns later.
  # Keep perltidy from making width decisions.
  push @pipe_cmd, '-l=9999';
  push @pipe_cmd, '-nbbc';

  #   push @pipe_cmd, '-nbbb';

  my $err = Symbol::gensym();
  my ( $in, $out );

  my $pid = eval { IPC::Open3::open3( $in, $out, $err, @pipe_cmd ) };

  if ( $@ ) {
    warn "Cannot run perltidy: $@";
    $self->_pt_debug_write_file( $idx, $perl );
    return ( 0, $perl );
  }

  print {$in} $perl;
  close $in;

  my ( $tidied, $errors ) = ( '', '' );
  my $sel = IO::Select->new( $out, $err );

  while ( my @ready = $sel->can_read ) {
    for my $fh ( @ready ) {
      my $buf = '';
      my $len = sysread $fh, $buf, 8192;

      if ( !defined $len ) {
        next if $!{EINTR};
        $sel->remove( $fh );
        next;
      }

      if ( $len == 0 ) {
        $sel->remove( $fh );
        next;
      }

      if ( fileno( $fh ) == fileno( $out ) ) {
        $tidied .= $buf;
      } else {
        $errors .= $buf;
      }
    }
  }

  waitpid $pid, 0;
  my $status = $? >> 8;

  open my $dbg, '>', './tmp/pt.raw-perltidy.out'
      or die "Cannot write ./tmp/pt.raw-perltidy.out: $!";
  print {$dbg} $tidied;
  close $dbg;

  return ( 1, $tidied ) if $status == 0 && length $tidied;

  warn "perltidy failed with status $status; writing debug file\n";
  warn $errors if length $errors;

  my $path = $self->_pt_debug_write_file( $idx, $perl );

  my @file_cmd = ( 'perltidy', '-b' );

  push @file_cmd, "-pro=$home_rc" if length $home_rc && -f $home_rc;

  # PrettyTidy owns wrapping/columns later.
  # Keep perltidy from making width decisions.
  push @file_cmd, '-l=9999';
  push @file_cmd, '-nbbc';

  # Debug mode: force sidecar LOG output.
  push @file_cmd, '-g';

  push @file_cmd, $path;
  warn "PERLTIDY PIPE CMD: @pipe_cmd\n";
  system @file_cmd;

  warn "perltidy debug input: $path\n";
  warn "perltidy debug log:   $path.LOG\n" if -f "$path.LOG";
  warn "perltidy debug err:   $path.ERR\n" if -f "$path.ERR";

  return ( 0, $perl );

}

sub _pt_template_from_region ( $self, $text ) {
  return '' unless defined $text && length $text;

  my @out;

  for my $line ( split /\n/, $text, -1 ) {
    if ( $line eq '' ) {
      push @out, '';
      next;
    }

    # Template payload carried through perltidy as:
    #
    #   0; # PrettyTidy:<html...>
    #
    # Keep perltidy's leading indent before the payload, but remove
    # the fake Perl marker itself.
    if ( $line =~ /^(\s*)0;\s*# PrettyTidy:(.*)\z/ ) {
      my ( $leading, $payload ) = ( $1, $2 );

      if ( $payload !~ /\S/ ) {
        push @out, '';
        next;
      }

      push @out, $leading . $payload;
      next;
    }

    # Real Perl code carried through perltidy.
    #
    # Preserve perltidy's leading/template indent before the EP marker,
    # but keep exactly one space between "%" and the Perl code.
    if ( $line =~ /^(\s*)(.*)\z/ ) {
      my ( $leading, $code ) = ( $1, $2 );

      $code =~ s/^\s+//;

      push @out, $leading . '% ' . $code;
      next;
    }
  }

  return join "\n", @out;
}

sub _remove_extra_newlines ( $self, $text ) {
  return '' unless defined $text && length $text;

  $text =~ s/\n{3,}/\n\n/g;

  return $text;
}

sub _separate_blocks ( $self, $text ) {
  return '' unless defined $text && length $text;

  # Mojo begin/end helper blocks.
  #
  # Handles:
  #   % my $cb = begin
  #     ...
  #   % end
  #
  # Keep begin/end helper regions visually separated from nearby payload.
  my @in = split /\n/, $text, -1;
  my @out;
  my $level = 0;

  for my $i ( 0 .. $#in ) {
    my $line = $in[$i];
    my $kind = $self->_ep_control( $line );

    if ( defined $kind && $kind eq 'end' ) {
      $level-- if $level > 0;
    }

    if (    defined $kind
         && $kind eq 'begin'
         && $level == 0
         && @out
         && $out[-1] ne '' )
    {
      push @out, '';
    }

    push @out, $line;

    if ( defined $kind && $kind eq 'end' && $level == 0 ) {
      my $next = $in[ $i + 1 ] // '';
      push @out, '' if $next =~ /\S/ && @out && $out[-1] ne '';
    }

    if ( defined $kind && $kind eq 'begin' ) {
      $level++;
    }
  }

# EP brace/control blocks.
#
# Handles:
#   % if (...) {
#     ...
#   % } else {
#     ...
#   % }
#
# Keep control blocks readable while avoiding a blank line before else/elsif/etc.

  my @in = split /\n/, $text, -1;
  my @out;
  my $depth = 0;

  for my $i ( 0 .. $#in ) {
    my $line = $in[$i];
    my $kind = $self->_ep_control( $line );

    my $leading = 0;
    $leading = length( $1 ) if $line =~ /\A(\s*)/;

    if ( defined $kind && ( $kind eq 'closer' || $kind eq 'transition' ) ) {
      $depth-- if $depth > 0;
    }

    if (    defined $kind
         && $kind eq 'opener'
         && $depth == 0
         && $leading == 0
         && @out
         && $out[-1] ne '' )
    {
      push @out, '';
    }

    push @out, $line;

    if (    defined $kind
         && $kind eq 'closer'
         && $depth == 0
         && $leading == 0 )
    {
      my $next = $in[ $i + 1 ] // '';

      if ( $next =~ /\S/ && $next !~ /^\s*%\s*(?:\}\s*)?(?:else|elsif)\b/ ) {
        push @out, '' unless @out && $out[-1] eq '';
      }
    }

    if ( defined $kind && ( $kind eq 'opener' || $kind eq 'transition' ) ) {
      $depth++;
    }
  }

  # Adjacent EP blocks / EP-to-payload boundaries.
  #
  # Handles EP statements or control lines that are glued to nearby
  # HTML/template payload.
  $text =~ s{
    \A
    (
      (?:
        %\s*(?:layout|title|my|our|state)\b[^\n]*;\n
      )+
    )
    (?=<[A-Za-z])
  }{$1\n}gx;

  # separate adjacent ep blocks
  my $tag = qr/[A-Za-z][A-Za-z0-9:_-]*/;
  my $ctl = qr/(?:if|unless|for|foreach|while)/;
  $text =~ s{(<$tag\b[^>]*>)\n(%\s*$ctl\b)}{$1\n\n$2}g;
  $text =~ s{(</$tag>)\n(%\s*$ctl\b)}{$1\n\n$2}g;
  return $text;

}

sub tidy ( $self, $input ) {
  my $text = defined $input ? $input : '';
  my $flat = $self->_flatten( $text );

  my @chunks = $self->_chunk( $flat );
  my $out    = $self->_pt_reemit_regions( @chunks );

  $out = $self->_html_separate_blocks( $out );
  $out = $self->_html_separate_landmarks( $out );

  $out = $self->_ep_postfix_indentation( $out );

  $out = $self->_separate_blocks( $out );
  $out = $self->_remove_extra_newlines( $out );

  return $out;
}

1;

##########################################################################
##########################################################################

# sub _reemit_begin_blocks ( $self, $text ) {
#   return '' unless defined $text && length $text;
#
#   my @out;
#   my $level  = 0;
#   my $indent = ' ' x $self->{indent_width};
#
#   for my $line ( split /\n/, $text, -1 ) {
#     my $kind = $self->_ep_control( $line );
#
#     if ( defined $kind && $kind eq 'end' ) {
#       $level-- if $level > 0;
#     }
#
#     if ( $level > 0 && length $line ) {
#       my $target  = $indent x $level;
#       my $leading = '';
#
#       if ( $line =~ /^(\s*)/ ) {
#         $leading = $1;
#       }
#
#       if ( length( $leading ) < length( $target ) ) {
#         $line =~ s/^\s*/$target/;
#       }
#     }
#
#     push @out, $line;
#
#     if ( defined $kind && $kind eq 'begin' ) {
#       $level++;
#     }
#   }
#
#   return join "\n", @out;
# }

#
# sub _separate_blocks
#
#     sub _separate_begin_blocks ( $self, $text ) {
#   return '' unless defined $text && length $text;
#
#   my @in = split /\n/, $text, -1;
#   my @out;
#   my $level = 0;
#
#   for my $i ( 0 .. $#in ) {
#     my $line = $in[$i];
#     my $kind = $self->_ep_control( $line );
#
#     if ( defined $kind && $kind eq 'end' ) {
#       $level-- if $level > 0;
#     }
#
#     if (    defined $kind
#          && $kind eq 'begin'
#          && $level == 0
#          && @out
#          && $out[-1] ne '' )
#     {
#       push @out, '';
#     }
#
#     push @out, $line;
#
#     if ( defined $kind && $kind eq 'end' && $level == 0 ) {
#       my $next = $in[ $i + 1 ] // '';
#       push @out, '' if $next =~ /\S/ && @out && $out[-1] ne '';
#     }
#
#     if ( defined $kind && $kind eq 'begin' ) {
#       $level++;
#     }
#   }
#
#   return join "\n", @out;
# }

# sub _separate_brace_blocks ( $self, $text ) {
#   return '' unless defined $text && length $text;
#
#   my @in = split /\n/, $text, -1;
#   my @out;
#   my $depth = 0;
#
#   for my $i ( 0 .. $#in ) {
#     my $line = $in[$i];
#     my $kind = $self->_ep_control( $line );
#
#     my $leading = 0;
#     $leading = length( $1 ) if $line =~ /\A(\s*)/;
#
#     if ( defined $kind && ( $kind eq 'closer' || $kind eq 'transition' ) ) {
#       $depth-- if $depth > 0;
#     }
#
#     if (    defined $kind
#          && $kind eq 'opener'
#          && $depth == 0
#          && $leading == 0
#          && @out
#          && $out[-1] ne '' )
#     {
#       push @out, '';
#     }
#
#     push @out, $line;
#
#     if (    defined $kind
#          && $kind eq 'closer'
#          && $depth == 0
#          && $leading == 0 )
#     {
#       my $next = $in[ $i + 1 ] // '';
#
#       if ( $next =~ /\S/ && $next !~ /^\s*%\s*(?:\}\s*)?(?:else|elsif)\b/ ) {
#         push @out, '' unless @out && $out[-1] eq '';
#       }
#     }
#
#     if ( defined $kind && ( $kind eq 'opener' || $kind eq 'transition' ) ) {
#       $depth++;
#     }
#   }
#
#   return join "\n", @out;
# }

# sub _separate_ep_blocks ( $self, $text ) {
#   return '' unless defined $text && length $text;
#
#   # separate initial ep statement block
#   $text =~ s{
#     \A
#     (
#       (?:
#         %\s*(?:layout|title|my|our|state)\b[^\n]*;\n
#       )+
#     )
#     (?=<[A-Za-z])
#   }{$1\n}gx;
#
#   # separate adjacent ep blocks
#   my $tag = qr/[A-Za-z][A-Za-z0-9:_-]*/;
#   my $ctl = qr/(?:if|unless|for|foreach|while)/;
#   $text =~ s{(<$tag\b[^>]*>)\n(%\s*$ctl\b)}{$1\n\n$2}g;
#   $text =~ s{(</$tag>)\n(%\s*$ctl\b)}{$1\n\n$2}g;
#   return $text;
# }

# sub _ep_logical_perl_code ( $self, $code ) {
#   return '' unless defined $code && length $code;
#
#   # Flattened native multiline EP continuation inside @{ ... }:
#   #   @{% $foo% }) {
#   # should be understood, for Perl scanning only, as:
#   #   @{$foo}) {
#   #
#   # Normal one-line Perl like @{$foo} does not match this and is left alone.
#   $code =~ s!\@\{\s*%\s*!\@\{!g;
#   $code =~ s{\s*%\s*(?=\}\)\s*\{)}{}g;
#
#   return $code;
# }

# sub _separate_adjacent_ep_blocks ( $self, $text ) {
#   return '' unless defined $text && length $text;
#
#   my $tag = qr/[A-Za-z][A-Za-z0-9:_-]*/;
#   my $ctl = qr/(?:if|unless|for|foreach|while)/;
#   $text =~ s{(<$tag\b[^>]*>)\n(%\s*$ctl\b)}{$1\n\n$2}g;
#   $text =~ s{(</$tag>)\n(%\s*$ctl\b)}{$1\n\n$2}g;
#
#   #   $text =~ s{(%\s*\}\s*)\n(%\s*$ctl\b)}{$1\n\n$2}g;
#   #   $text =~ s{(%\s*\}\s*)\n(</$tag>)}{$1\n\n$2}g;
#
#   return $text;
# }

# sub _pt_ensure_tmp_dir ( $self ) {
#   require File::Path;
#
#   my $dir = $self->_pt_tmp_dir;
#
#   File::Path::make_path( $dir ) unless -d $dir;
#
#   return $dir;
# }

# sub _pt_tmp_dir ( $self ) {
#   require Cwd;
#   require File::Basename;
#   require File::Spec;
#
#   my $module_dir = File::Basename::dirname( __FILE__ );
#   my $root = Cwd::abs_path( File::Spec->catdir( $module_dir, '..', '..' ) );
#
#   die "Cannot resolve project root from " . __FILE__ . "\n"
#       unless defined $root && length $root;
#
#   return File::Spec->catdir( $root, 'tmp', 'perltidy' );
# }

# sub _pt_region_supported ( $self, $perl ) {
#   return 0 unless defined $perl && length $perl;
#
#   # Mojo/debug templates often contain multiline constructs like:
#   #   for my $line (@{
#   #     ...
#   #   }) {
#   return 0 if $perl =~ /\@\{\s*(?:\n|\z)/;
#
#   # Also skip regions containing Mojo's "begin" helper style until we handle it
#   # deliberately.
#   return 0 if $perl =~ /\bbegin\s*(?:\n|\z)/;
#
#   return 1;
# }
#
# sub _debug_action_block_slice ( $self, $label, $text ) {
#   return unless defined $text;
#
#   if ( $text =~ /(% for my \$t .*?% \} else \{.*?<em>dev<\/em>.*?% \})/s ) {
#     my $slice = $1;
#     $slice =~ s/ /·/g;
#     $slice =~ s/\n/⏎\n/g;
#
#     warn
# "\n--- $label action-block ---\n$slice\n--- end $label action-block ---\n";
#   }
#
#   return;
# }

# sub _pt_compact_region ( $self, $text ) {
#   return '' unless defined $text && length $text;
#
#   my @out = grep {/\S/} split /\n/, $text, -1;
#
#   return join "\n", @out;
# }
#
# sub _debug_has_lines_before_blank ( $self, $label, $text ) {
#   return unless defined $text;
#
#   if (
#     $text =~
# /lines_before.*?\n.*?%=\s*\$cv->\(\$line->\[0\],\s*\$line->\[1\]\).*?\n\s*%\s*\}\s*\
# n\n\s*%\s*if/s )
#   {
#     warn "BLANK PRESENT after $label\n";
#   } else {
#     warn "blank absent after $label\n";
#   }
#
#   return;
# }
#
# sub _debug_lines_before_slice ( $self, $label, $text ) {
#   return unless defined $text;
#
#   if ( $text =~ /(<table class="wide">.*?<\/table>)/s ) {
#     warn "\n--- $label ---\n$1\n--- end $label ---\n";
#   }
#
#   return;
# }
#
# sub _debug_script_slice ( $self, $label, $text ) {
#   return unless defined $text;
#
#   my $needle = '<script';
#   my $pos    = 0;
#   my $seen   = 0;
#
#   while ( ( $pos = index( lc( $text ), $needle, $pos ) ) >= 0 ) {
#     $seen++;
#
#     my $start = $pos - 20;
#     $start = 0 if $start < 0;
#
#     my $len   = 40;
#     my $slice = substr( $text, $start, $len );
#
#     $slice =~ s/\n/⏎\n/g;
#
#     warn "\n--- $label script#$seen pos=$pos ---\n$slice\n--- end $label
# script#$seen ---\n";
#
#     $pos += length $needle;
#   }
#
#   warn "\n--- $label no <script> found ---\n" if !$seen;
#
#   return;
# }
#
# sub _normalize_ep_multiline_deref_blocks ( $self, $text ) {
#   return '' unless defined $text && length $text;
#
#   my @in = split /\n/, $text, -1;
#   my @out;
#
#   my $in_deref_header = 0;
#
#   for my $line ( @in ) {
#     if ( $in_deref_header && $line !~ /^\s*%/ && $line =~ /\S/ ) {
#       $line =~ s/^\s+//;
#       $line = "  % $line";
#     }
#
#     push @out, $line;
#
#     $in_deref_header = 0;
#
#     if ( $line =~ /^\s*%\s*(?:if|unless|for|foreach|while)\b.*\@\{\s*$/ ) {
#       $in_deref_header = 1;
#     }
#   }
#
#   return join "\n", @out;
# }
#
# sub _normalize_indented_output_lines ( $self, $text ) {
#   return '' unless defined $text && length $text;
#
#   $text =~ s{^[ \t]+(?=%=)}{  }gm;
#
#   return $text;
# }
#
# sub _perl_control_opener_complete ( $self, $code ) {
#   my $paren = 0;
#   my $brack = 0;
#   my $brace = 0;
#
#   my @chars = split //, $code;
#
#   for my $ch ( @chars ) {
#     if ( $ch eq '(' ) { $paren++;               next }
#     if ( $ch eq ')' ) { $paren-- if $paren > 0; next }
#
#     if ( $ch eq '[' ) { $brack++;               next }
#     if ( $ch eq ']' ) { $brack-- if $brack > 0; next }
#
#     if ( $ch eq '{' ) {
#       if ( $paren == 0 && $brack == 0 && $brace == 0 ) {
#         return 1;    # block opener
#       }
#
#       $brace++;
#       next;
#     }
#
#     if ( $ch eq '}' ) {
#       $brace-- if $brace > 0;
#       next;
#     }
#   }
#
#   return 0;
# }
#
# sub _separate_output_before_control ( $self, $text ) {
#   return '' unless defined $text && length $text;
#   $text =~
#       s{(^%=\s+[^\n]+)\n(%\s*(?:if|unless|for|foreach|while)\b)}{$1\n\n$2}gm;
#
#   return $text;
# }
