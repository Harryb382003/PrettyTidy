use v5.40.0;
use common::sense;
use feature 'signatures';

use lib 'lib';
use Test::More;
use Mojo::PrettyTidy;

my $pt = Mojo::PrettyTidy->new( indent_width => 2 );

subtest 'anchor line with inline text is left alone' => sub {
  my $in = "<a href=\"/x\">First</a>\n";

  my $expected = "<a href=\"/x\">First</a>\n";

  is $pt->tidy( $in ), $expected, 'inline anchor content is not reformatted';
};

subtest 'attribute-level EP line keeps structure, inherits outer indent' =>
    sub {
  my $in = "<div>\n<a href=\"<%= \$url %>\">Link</a>\n</div>\n";

  my $expected = "<div>\n  <a href=\"<%= \$url %>\">Link</a>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'attribute-level EP line is not reindented';
    };

subtest 'closing div after script and EP block stays aligned' => sub {
  my $in = join "\n",
      "<div>",
      "% if (\$show) {",
      "<script>",
      "function x() {",
      "return 1;",
      "}",
      "</script>",
      "% }",
      "</div>",
      "";

  my $expected = join "\n",
      "<div>",
      "  % if (\$show) {",
      "    <script>",
      "      function x() {",
      "      return 1;",
      "      }",
      "    </script>",
      "  % }",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'closing div after script and EP block stays aligned';
};

subtest 'closing percent cluster stays visually coherent in mixed ep block' =>
    sub {
  my $in = join "\n",
      "<div>",
"    % # light delimiter between tier2 groups (only if there are multiple)",
      "  % if (\$show_tier2 && \$gi < \$#\$groups) {",
      "    <%= \$light_hr %>",
      "  % }",
      "  % } # groups loop",
      "  % } # groups present",
      "  </div>",
      "";

  my $expected = join "\n",
      "<div>",
      "  % # light delimiter between tier2 groups (only if there are multiple)",
      "  % if (\$show_tier2 && \$gi < \$#\$groups) {",
      "    <%= \$light_hr %>",
      "  % }",
      "  % } # groups loop",
      "  % } # groups present",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'closing percent cluster stays visually coherent';
    };

subtest 'columns expands simple nested tag line vertically' => sub {
  my $pt = Mojo::PrettyTidy->new(
                                  indent_width => 2,
                                  tab_width    => 2,
                                  columns      => 20, );

  my $in = "<td><code><%= \$t->{ih} %></code></td>\n";

  my $expected = join "\n",
      "<td>",
      "  <code>",
      "    <%= \$t->{ih} %>",
      "  </code>",
      "</td>",
      "";

  is $pt->tidy( $in ), $expected,
      'long simple nested tag line expands vertically';
};

subtest 'columns expands long indented one-line opening tag with style into
multiline style form' => sub {
  my $pt = Mojo::PrettyTidy->new(
                                  indent_width => 2,
                                  tab_width    => 2,
                                  columns      => 40, );

  my $in = join '',
      '  <div class="qbtl-actions" style="display:flex; flex-wrap:wrap; ',
      'gap:6px; align-items:center;">',
      "\n";

  my $expected = join "\n",
      '<div class="qbtl-actions" style="',
      '    display:flex;',
      '    flex-wrap:wrap;',
      '    gap:6px;',
      '    align-items:center;">',
      '';

  is $pt->tidy( $in ), $expected,
      'long indented opening tag paginates at style attribute';
};

subtest
    'columns expands long nested html comment into multiline comment block' =>
    sub {

  local $TODO = 'not yet implemented';

  my $pt = Mojo::PrettyTidy->new(
                                  indent_width => 2,
                                  tab_width    => 2,
                                  columns      => 40, );

  my $comment =
        '  <!-- this is a long comment that should '
      . 'become a multiline comment block -->';

  my $in = join "\n", "<div>", $comment, "</div>", "";

  my $expected = join "\n",
      "<div>",
      "  <!--",
      "  this is a long comment that should become a multiline comment block",
      "  -->",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'long nested html comment expands into multiline comment block';
    };

subtest 'doctype line is kept at current level' => sub {
  my $in = "<!DOCTYPE html>\n<div>\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<!DOCTYPE html>\n<div>\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'doctype line stays neutral and does not affect nesting';
};

subtest 'embedded percent code lines align with sibling form content' => sub {
  my $in = join "\n",
      "<form>",
      "<input type=\"hidden\" name=\"confirm\" value=\"1\">",
      "% my \$return_to = '/';",
      "% my \$qs = '';",
      "% \$return_to .= \"?\$qs\" if length \$qs;",
      "<input type=\"hidden\" name=\"return_to\" value=\"<%= \$return_to %>\">",
      "<button type=\"submit\">Add</button>",
      "</form>",
      "";

  my $expected = join "\n",
      "<form>",
      "  <input type=\"hidden\"",
      "    name=\"confirm\"",
      "    value=\"1\">",
      "  % my \$return_to = '/';",
      "  % my \$qs = '';",
      "  % \$return_to .= \"?\$qs\" if length \$qs;",
      "  <input type=\"hidden\"",
      "    name=\"return_to\"",
      "    value=\"<%= \$return_to %>\">",
      "  <button type=\"submit\">",
      "    Add",
      "  </button>",
      "</form>",
      "";

  is $pt->tidy( $in ), $expected,
      'embedded percent code lines align with sibling content';
};

subtest 'embedded percent code lines indent locally inside html block' => sub {
  my $in = join "\n",
      "<form>",
      "<input type=\"hidden\" name=\"confirm\" value=\"1\">",
      "% my \$return_to = '/';",
      "% my \$qs = '';",
      "% \$return_to .= \"?\$qs\" if length \$qs;",
      "<input type=\"hidden\" name=\"return_to\" value=\"<%= \$return_to %>\">",
      "<button type=\"submit\">Add</button>",
      "</form>",
      "";

  my $expected = join "\n",
      "<form>",
      "  <input type=\"hidden\"",
      "    name=\"confirm\"",
      "    value=\"1\">",
      "  % my \$return_to = '/';",
      "  % my \$qs = '';",
      "  % \$return_to .= \"?\$qs\" if length \$qs;",
      "  <input type=\"hidden\"",
      "    name=\"return_to\"",
      "    value=\"<%= \$return_to %>\">",
      "  <button type=\"submit\">",
      "    Add",
      "  </button>",
      "</form>",
      "";

  is $pt->tidy( $in ), $expected,
      'embedded percent code lines inherit local indentation';
};

subtest 'ep wrapper keeps opening and closing html aligned' => sub {
  my $in = join "\n", "% if (\$show) {", "<div>", "</div>", "% }", "";

  my $expected = join "\n", "% if (\$show) {", "  <div>", "  </div>", "% }", "";

  is $pt->tidy( $in ), $expected,
      'opening and closing tags stay aligned inside EP block';
};

subtest 'ep wrapper with inner branch keeps plain text, links aligned' => sub {
  my $in = join "\n",
      "% if (\$pages > 1) {",
      "<div>",
      "% if (\$page > 1) {",
      "<a>First</a>",
      "|",
      "<a>Prev</a>",
      "% } else {",
      "First | Prev",
      "% }",
      "</div>",
      "% }",
      "";

  my $expected = join "\n",
      "% if (\$pages > 1) {",
      "  <div>",
      "  % if (\$page > 1) {",
      "    <a>First</a>",
      "    |",
      "    <a>Prev</a>",
      "  % } else {",
      "    First | Prev",
      "  % }",
      "  </div>",
      "% }",
      "";

  is $pt->tidy( $in ), $expected,
      'plain text inside nested EP branch follows surrounding html depth';
};

subtest 'for-loop row block uses local readable indentation' => sub {
  my $in = join "\n",
      "% for my \$t (\@\$sample) {",
      "<tr>",
      "<td><%= \$t->{name} %></td>",
      "<td><code><%= \$t->{ih} %></code></td>",
      "<td>",
      "% if (stash('dev_mode')) {",
      "<div class=\"qbtl-actions\">",
      "<form method=\"post\" action=\"/qbt/add_one\">",
      "<input type=\"hidden\" name=\"ih\" value=\"<%= \$t->{ih} %>\">",
      "<button type=\"submit\">Add</button>",
      "</form>",
      "</div>",
      "% } else {",
      "<em>dev</em>",
      "% }",
      "</td>",
      "</tr>",
      "% }",
      "";

  my $expected = join "\n",
      '% for my $t (@$sample) {',
      '  <tr>',
      '    <td><%= $t->{name} %></td>',
      '    <td><code><%= $t->{ih} %></code></td>',
      '    <td>',
      "    % if (stash('dev_mode')) {",
      '      <div class="qbtl-actions">',
      '        <form method="post"',
      '            action="/qbt/add_one">',
      '          <input type="hidden"',
      '            name="ih"',
      '            value="<%= $t->{ih} %>">',
      '          <button type="submit">',
      '            Add',
      '          </button>',
      '        </form>',
      '      </div>',
      '    % } else {',
      '      <em>dev</em>',
      '    % }',
      '    </td>',
      '  </tr>',
      '% }',
      '';

  is $pt->tidy( $in ), $expected,
      'html inside for-loop stays readable without excessive rightward drift';
};

subtest 'for-loop td lines align under tr' => sub {
  my $in = join "\n",
      "% for my \$t (\@\$sample) {",
      "<tr>",
      "<td><%= \$t->{name} %></td>",
      "<td><code><%= \$t->{ih} %></code></td>",
      "</tr>",
      "% }",
      "";

  my $expected = join "\n",
      "% for my \$t (\@\$sample) {",
      "  <tr>",
      "    <td><%= \$t->{name} %></td>",
      "    <td><code><%= \$t->{ih} %></code></td>",
      "  </tr>",
      "% }",
      "";

  is $pt->tidy( $in ), $expected, 'td lines align under tr inside for-loop';
};

subtest 'html comment line is kept at current level' => sub {
  my $in = "<div>\n<!-- note -->\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n  <!-- note -->\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'comment line is indented to current level';
};

subtest 'html comment near EP lines is left safe' => sub {
  my $in = "<div>\n<%= \$title %>\n<!-- note -->\n<p>\nHello\n</p>\n</div>\n";

  my $expected =
"<div>\n  <%= \$title %>\n  <!-- note -->\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'comment line indents normally while EP line stays untouched';
};

subtest 'html root stays neutral while head and body remain top-level' => sub {
  my $in = join "\n",
      '<!DOCTYPE html>',
      '<html>',
      '<head>',
      '<title>Hi</title>',
      '</head>',
      '<body>',
      '<h1>Hello</h1>',
      '</body>',
      '</html>',
      '';

  my $expected = join "\n",
      '<!DOCTYPE html>',
      '<html>',
      '<head>',
      '  <title>Hi</title>',
      '</head>',
      '<body>',
      '  <h1>Hello</h1>',
      '</body>',
      '</html>',
      '';

  is $pt->tidy( $in ), $expected,
      'html root is neutral and does not indent head/body';
};

subtest 'html root stays neutral with top-level comment and ep in head' => sub {
  my $in = join "\n",
      '<!DOCTYPE html>',
      '<!-- Request ID: <%= $c->req->request_id %> -->',
      '<html>',
      '<head>',
      '% my $title = "Hi";',
      '<title><%= $title %></title>',
      '</head>',
      '<body>',
      '<h1>Hello</h1>',
      '</body>',
      '</html>',
      '';

  my $expected = join "\n",
      '<!DOCTYPE html>',
      '<!-- Request ID: <%= $c->req->request_id %> -->',
      '<html>',
      '<head>',
      '  % my $title = "Hi";',
      '  <title><%= $title %></title>',
      '</head>',
      '<body>',
      '  <h1>Hello</h1>',
      '</body>',
      '</html>',
      '';

  is $pt->tidy( $in ), $expected,
      'html root stays neutral with top-level comment and EP in head';
};

subtest 'inline EP in html line is left alone' => sub {
  my $in = "<div>\n<div><%= \$name %></div>\n</div>\n";

  my $expected = "<div>\n  <div><%= \$name %></div>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'inline EP line is not reindented';
};

subtest 'label line with inline text is left alone' => sub {
  my $in = "<label>Search:</label>\n";

  my $expected = "<label>Search:</label>\n";

  is $pt->tidy( $in ), $expected, 'inline label content is not reformatted';
};

subtest 'leading EP tag lines are left alone' => sub {
  my $in = "<%= \$title %>\n<div>\n<span>\nHi\n</span>\n</div>\n";

  my $expected = "<%= \$title %>\n<div>\n  <span>\n    Hi\n  </span>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'leading EP tag lines remain untouched';
};

subtest 'mixed EP block tag line is left alone' => sub {
  my $in = "<div>\n<% if (\$ok) { %>\n<p>Hello</p>\n<% } %>\n</div>\n";

  my $expected =
      "<div>\n  <% if (\$ok) { %>\n  <p>Hello</p>\n  <% } %>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'mixed EP block lines are not reindented';
};

subtest 'mixed ep micro block stays visually coherent' => sub {
  my $in = join "\n",
      "<div>",
      "  % # light delimiter between tier2 groups (only if there are multiple)",
      "% if (\$show_tier2 && \$gi < \$#\$groups) {",
      "  <%= \$light_hr %>",
      "% }",
      "% } # groups loop",
      "% } # groups present",
      "</div>",
      "";

  my $expected = join "\n",
      "<div>",
      "  % # light delimiter between tier2 groups (only if there are multiple)",
      "  % if (\$show_tier2 && \$gi < \$#\$groups) {",
      "    <%= \$light_hr %>",
      "  % }",
      "  % } # groups loop",
      "  % } # groups present",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'mixed ep micro block stays visually coherent';
};

subtest 'mixed inline children align under parent' => sub {
  my $in = join "\n",
      "<div>",
      '<div style="margin-top:12px; border-top:1px solid #2a2a2a; '
      . 'padding-top:10px;">',
      '  <div id="vmCount" style="font-weight:700; '
      . 'margin-bottom:6px;">Contents</div>',
      '  <ul id="vmList" style="margin:0; padding-left:18px; '
      . 'line-height:1.35;"></ul>',
      "</div>",
      "</div>",
      "";

  my $expected = join "\n",
      "<div>",
      '  <div style="margin-top:12px; border-top:1px solid #2a2a2a; '
      . 'padding-top:10px;">',
      '    <div id="vmCount" style="font-weight:700; '
      . 'margin-bottom:6px;">Contents</div>',
      '    <ul id="vmList" style="margin:0; padding-left:18px; '
      . 'line-height:1.35;"></ul>',
      "  </div>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'mixed inline child lines align under parent block';
};

subtest 'multiline button tags stay aligned and readable' => sub {
  my $in = join "\n",
      "<div>",
      "<form>",
      "<button type=\"submit\"",
      "style=\"background:#2d6cdf;",
      "color:#fff; border:0;",
      "border-radius:8px;\">",
      "Add",
      "</button>",
      "</form>",
      "<button type=\"button\"",
      "onclick=\"qbtlCloseViewModal()\"",
      "style=\"background:#2b2b2b;",
      "color:#eee;",
      "border:1px solid #444;\">",
      "Done",
      "</button>",
      "</div>",
      "";

  my $expected = join "\n",
      "<div>",
      "  <form>",
      "    <button type=\"submit\"",
      "      style=\"background:#2d6cdf;",
      "      color:#fff; border:0;",
      "      border-radius:8px;\">",
      "      Add",
      "    </button>",
      "  </form>",
      "  <button type=\"button\"",
      "    onclick=\"qbtlCloseViewModal()\"",
      "    style=\"background:#2b2b2b;",
      "    color:#eee;",
      "    border:1px solid #444;\">",
      "    Done",
      "  </button>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'multiline button tags align with surrounding block';
};

subtest 'multiline html comment block is indented consistently' => sub {
  my $in = "<div>\n<!--\ncomment\n-->\n<p>\nHello\n</p>\n</div>\n";

  my $expected =
      "<div>\n  <!--\n  comment\n  -->\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'multiline comment block is indented at the current level';
};

subtest 'multiline html comment near EP lines keeps EP safe' => sub {
  my $in =
        "<div>\n"
      . "<%= \$title %>\n"
      . "<!--\n"
      . "note\n" . "-->\n" . "<p>\n"
      . "Hello\n"
      . "</p>\n"
      . "</div>\n";

  my $expected =
        "<div>\n"
      . "  <%= \$title %>\n"
      . "  <!--\n"
      . "  note\n"
      . "  -->\n"
      . "  <p>\n"
      . "    Hello\n"
      . "  </p>\n"
      . "</div>\n";

  is $pt->tidy( $in ), $expected,
      'multiline comment block indents normally while EP line stays untouched';
};

subtest 'multiline inline style indents cleanly' => sub {
  my $in =
        "<div style=\"\nposition:absolute;\n"
      . "top:6%;\nleft:50%;\ntransform:translateX(-50%);\n \">\n</div>\n";

  my $expected = join "\n",
      '<div style="',
      '    position:absolute;',
      '    top:6%;',
      '    left:50%;',
      '    transform:translateX(-50%);">',
      '</div>',
      '';

  is $pt->tidy( $in ), $expected,
      'multiline inline style declarations are indented';
};

subtest 'multiline inline style closes on final declaration line' => sub {
  my $in = join "\n",
      "<div style=\"",
      "background:#151515;",
      "color:#eee;",
      "font-family: system-ui, -apple-system, sans-serif;",
      "\">",
      "</div>",
      "";

  my $expected = join "\n",
      "<div style=\"",
      "    background:#151515;",
      "    color:#eee;",
      "    font-family: system-ui, -apple-system, sans-serif;\">",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'inline style closes on final declaration line';
};

subtest 'multiline inline style with EP is left alone' => sub {
  my $in =
"<div style=\"\ncolor:<%= \$color %>;\nbackground:#151515;\n\">\n</div>\n";

  my $expected = join "\n",
      '<div style="',
      '    color:<%= $color %>;',
      '    background:#151515;">',
      '</div>',
      '';

  is $pt->tidy( $in ), $expected,
      'multiline inline style attribute containing EP is not reformatted';
};

subtest 'multiline inline style with inline content under form stays aligned' =>
    sub {
  my $in = join "\n",
      "<form>",
      "<button type=\"submit\" style=\"",
      "background:#2d6cdf;",
      "color:#fff;",
      "cursor:pointer;\">Add</button>",
      "</form>",
      "";

  my $expected = join "\n",
      "<form>",
      "  <button type=\"submit\" style=\"",
      "      background:#2d6cdf;",
      "      color:#fff;",
      "      cursor:pointer;\">",
      "    Add",
      "  </button>",
      "</form>",
      "";

  is $pt->tidy( $in ), $expected,
      'multiline inline style button stays aligned inside form';
    };

subtest 'multiline inline style with inline content splits into block form' =>
    sub {
  my $in = join "\n",
      "<div>",
      "<button type=\"submit\" style=\"",
      "background:#2d6cdf;",
      "color:#fff;",
      "border:0;",
      "border-radius:8px;",
      "padding:8px 12px;",
      "font-weight:600;",
      "cursor:pointer;\">Add</button>",
      "</div>",
      "";

  my $expected = join "\n",
      "<div>",
      "  <button type=\"submit\" style=\"",
      "      background:#2d6cdf;",
      "      color:#fff;",
      "      border:0;",
      "      border-radius:8px;",
      "      padding:8px 12px;",
      "      font-weight:600;",
      "      cursor:pointer;\">",
      "    Add",
      "  </button>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'multiline inline style with inline content becomes block form';
    };

subtest 'multiline inline style anchor becomes block form' => sub {
  my $in = join "\n",
      "<a href=\"<%= \$back %>\" style=\"",
      "display:inline-flex;",
      "align-items:center;",
      "text-decoration:none;\">Back</a>",
      "";

  my $expected = join "\n",
      "<a href=\"<%= \$back %>\" style=\"",
      "    display:inline-flex;",
      "    align-items:center;",
      "    text-decoration:none;\">",
      "  Back",
      "</a>",
      "";

  is $pt->tidy( $in ), $expected,
      'inline style anchor closes on declaration line and splits content';
};

subtest 'multiline opening tag aligns under parent' => sub {
  my $in = join "\n",
      "<div>",
      "<button type=\"submit\"",
      "style=\"background:#2d6cdf;\"",
      "onclick=\"x()\">",
      "</button>",
      "</div>",
      "";

  my $expected = join "\n",
      "<div>",
      "  <button type=\"submit\"",
      "    style=\"background:#2d6cdf;\"",
      "    onclick=\"x()\">",
      "  </button>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected, 'multiline opening tag aligns under parent';
};

subtest 'nested multiline inline style follows html indentation' => sub {
  my $in = join "\n",
      "<div>",
      "<div style=\"",
      "position:absolute;",
      "top:6%;",
      "left:50%;",
      "\">",
      "</div>",
      "</div>",
      "";

  my $expected = join "\n",
      '<div>',
      '  <div style="',
      '      position:absolute;',
      '      top:6%;',
      '      left:50%;">',
      '  </div>',
      '</div>',
      '';

  is $pt->tidy( $in ), $expected,
      'multiline inline style declarations follow surrounding html indentation';
};

subtest 'nested div after script block closes cleanly' => sub {
  my $in = join "\n",
      "<div>",
      "<div>",
      "% if (\$show) {",
      "<script>",
      "function x() {",
      "return 1;",
      "}",
      "</script>",
      "% }",
      "</div>",
      "</div>",
      "";

  my $expected = join "\n",
      "<div>",
      "  <div>",
      "    % if (\$show) {",
      "      <script>",
      "        function x() {",
      "        return 1;",
      "        }",
      "      </script>",
      "    % }",
      "  </div>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'nested divs stay aligned after script and EP boundaries';
};

subtest 'nested EP control lines indent locally' => sub {
  my $in = join "\n",
      "% for my \$t (\@\$sample) {",
      "<tr>",
      "<td>",
      "% if (stash('dev_mode')) {",
      "<div>",
      "<form>",
      "</form>",
      "</div>",
      "% }",
      "</td>",
      "</tr>",
      "% }",
      "";

  my $expected = join "\n",
      "% for my \$t (\@\$sample) {",
      "  <tr>",
      "    <td>",
      "    % if (stash('dev_mode')) {",
      "      <div>",
      "        <form>",
      "        </form>",
      "      </div>",
      "    % }",
      "    </td>",
      "  </tr>",
      "% }",
      "";

  is $pt->tidy( $in ), $expected,
      'nested EP control lines inherit local indentation';
};

subtest 'single-line inline style attribute is left alone' => sub {
  my $in = qq{<div style="position:absolute; top:6%; left:50%;">\n</div>\n};

  my $expected =
      qq{<div style="position:absolute; top:6%; left:50%;">\n</div>\n};

  is $pt->tidy( $in ), $expected,
      'single-line inline style attribute is left untouched';
};

subtest 'paginate per-page block keeps html structure near EP lines' => sub {
  my $in = join "\n",
      "% if (\$mode eq 'paginate') {",
      "<label>",
      "Per page:",
      "<select>",
      "% for my \$n (20, 50) {",
      "<option>n</option>",
      "% }",
      "</select>",
      "</label>",
      "<input>",
      "% }",
      "";

  my $expected = join "\n",
      "% if (\$mode eq 'paginate') {",
      "  <label>",
      "    Per page:",
      "    <select>",
      "    % for my \$n (20, 50) {",
      "      <option>n</option>",
      "    % }",
      "    </select>",
      "  </label>",
      "  <input>",
      "% }",
      "";

  is $pt->tidy( $in ), $expected,
      'html remains nested correctly around paginate EP lines';
};

subtest 'paragraph line with inline EP is left alone' => sub {
  my $in = "Found: <%= \$found %>\n";

  my $expected = "Found: <%= \$found %>\n";

  is $pt->tidy( $in ), $expected, 'inline EP content line is not reformatted';
};

subtest
'percent code lines normalize space after percent and indent as block content'
    => sub {
  my $in = join "\n",
      "<tbody>",
      "% for my \$r (\@\$rows) {",
      "%   \$r = {} if ref(\$r) ne 'HASH';",
      "%   my \$name = \$r->{name} // '';",
      "<tr>",
      "</tr>",
      "% }",
      "</tbody>",
      "";

  my $expected = join "\n",
      "<tbody>",
      "  % for my \$r (\@\$rows) {",
      "    % \$r = {} if ref(\$r) ne 'HASH';",
      "    % my \$name = \$r->{name} // '';",
      "    <tr>",
      "    </tr>",
      "  % }",
      "</tbody>",
      "";

  is $pt->tidy( $in ), $expected,
      'percent lines use a single space after percent';
    };

subtest 'percent directive lines are left structurally alone' => sub {
  my $in = "% if (\$ok) {\n<div>\n<p>Hello</p>\n</div>\n% }\n";

  my $expected = "% if (\$ok) {\n  <div>\n    <p>Hello</p>\n  </div>\n% }\n";

  is $pt->tidy( $in ), $expected, 'percent directive lines remain untouched';
};

subtest 'plain text inside nested html is indented to current level' => sub {
  my $in = "<div>\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'plain text line is indented inside nested tags';
};

subtest 'plain text navigation fallback inside EP block is indented' => sub {
  my $in = join "\n", "% if (\$page > 1) {", "First | Prev", "% }", "";

  my $expected = join "\n", "% if (\$page > 1) {", "  First | Prev", "% }", "";

  is $pt->tidy( $in ), $expected,
      'plain fallback text follows EP indentation level';
};

subtest 'plain text near EP lines indented but EP lines are left alone' => sub {
  my $in = "<div>\n<%= \$title %>\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<div>\n  <%= \$title %>\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'plain text is indented and EP line is preserved';
};

subtest 'single-line mixed tag/content lines are left alone' => sub {
  my $in = "<div>\n<p>Hello</p>\n</div>\n";

  my $expected = "<div>\n  <p>Hello</p>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'mixed content line is left alone';
};

subtest 'script block indented, interior lines left structurally alone' => sub {
  my $in =
        "<div>\n"
      . "<script>\n"
      . "if (x < 10) {\n"
      . "console.log(x);\n" . "}\n"
      . "</script>\n"
      . "</div>\n";

  my $expected =
        "<div>\n"
      . "  <script>\n"
      . "    if (x < 10) {\n"
      . "    console.log(x);\n"
      . "    }\n"
      . "  </script>\n"
      . "</div>\n";

  is $pt->tidy( $in ), $expected,
      'script wrapper lines indent, script body is left alone';
};

subtest 'script block interior lines get one local indent level' => sub {
  my $in = join "\n",
      "<script>",
      "(function () {",
      "function poll() {",
      "poll();",
      "}",
      "})();",
      "</script>",
      "";

  my $expected = join "\n",
      "<script>",
      "  (function () {",
      "  function poll() {",
      "  poll();",
      "  }",
      "  })();",
      "</script>",
      "";

  is $pt->tidy( $in ), $expected,
      'script interior lines are indented one local level';
};

subtest 'script block near EP lines keeps EP safe' => sub {
  my $in = "<div>\n<%= \$title %>\n<script>\nif (x < 10) {"
      . "\nconsole.log(x);\n}\n</script>\n</div>\n";

  my $expected = join "\n",
      "<div>",
      "  <%= \$title %>",
      "  <script>",
      "    if (x < 10) {",
      "    console.log(x);",
      "    }",
      "  </script>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'script block indents normally while EP line stays untouched';
};

subtest 'script block with inline attributes is handled safely' => sub {
  my $in =
        "<div>\n"
      . "<script type=\"text/javascript\">\n"
      . "if (x < 10) {\n"
      . "console.log(x);\n" . "}\n"
      . "</script>\n"
      . "</div>\n";

  my $expected = join "\n",
      "<div>",
      "  <script type=\"text/javascript\">",
      "    if (x < 10) {",
      "    console.log(x);",
      "    }",
      "  </script>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'script block with attributes is treated as a protected block';
};

subtest 'separator text line inside EP block is indented as plain text' => sub {
  my $in = join "\n", "% if (\$page > 1) {", "|", "% }", "";

  my $expected = join "\n", "% if (\$page > 1) {", "  |", "% }", "";

  is $pt->tidy( $in ), $expected,
      'plain separator text follows EP indentation level';
};

subtest 'single-line css rule stays alone inside style block' => sub {
  my $in = join "\n",
      "<style>",
      '@keyframes qbtl-spin { to { transform: rotate(360deg); } }',
      "</style>",
      "";

  my $expected = join "\n",
      "<style>",
      '  @keyframes qbtl-spin { to { transform: rotate(360deg); } }',
      "</style>",
      "";

  is $pt->tidy( $in ), $expected,
      'single-line css rule remains unchanged apart from block indent';
};

subtest 'style block applies simple brace-aware indentation' => sub {
  my $in = "<div>\n<style>\n.foo {\ncolor: red;\n}\n</style>\n</div>\n";

  my $expected = join "\n",
      "<div>",
      "  <style>",
      "    .foo {",
      "      color: red;",
      "    }",
      "  </style>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'style wrapper lines indent, style body is left alone';
};

subtest 'style block with css braces indents inner declarations' => sub {
  my $in = join "\n",
      "<style>",
      ".qbtl-spinner {",
      "display: inline-block;",
      "width: 14px;",
      "}",
      "</style>",
      "";

  my $expected = join "\n",
      "<style>",
      "  .qbtl-spinner {",
      "    display: inline-block;",
      "    width: 14px;",
      "  }",
      "</style>",
      "";

  is $pt->tidy( $in ), $expected,
      'style interior lines are indented one local level';
};

subtest 'style block near EP lines keeps EP safe and indents body' => sub {
  my $in =
"<div>\n<%= \$title %>\n<style>\n.foo {\ncolor: red;\n}\n</style>\n</div>\n";

  my $expected = join "\n",
      "<div>",
      "  <%= \$title %>",
      "  <style>",
      "    .foo {",
      "      color: red;",
      "    }",
      "  </style>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'style block indents normally while EP line stays untouched';
};

subtest 'style block with inline attributes keeps body indented' => sub {
  my $in =
"<div>\n<style media=\"screen\">\n.foo {\ncolor: red;\n}\n</style>\n</div>\n";

  my $expected = join "\n",
      "<div>",
      "  <style media=\"screen\">",
      "    .foo {",
      "      color: red;",
      "    }",
      "  </style>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'style block with attributes is treated as a protected block';
};

subtest 'style block with simple braces gets inner indent' => sub {
  my $in = join "\n",
      "<style>",
      ".qbtl-spinner {",
      "display: inline-block;",
      "width: 14px;",
      "}",
      "</style>",
      "";

  my $expected = join "\n",
      "<style>",
      "  .qbtl-spinner {",
      "    display: inline-block;",
      "    width: 14px;",
      "  }",
      "</style>",
      "";

  is $pt->tidy( $in ), $expected,
      'style block applies simple inner brace indentation';
};

subtest 'td action block stays aligned across EP branch' => sub {
  my $in = join "\n",
      "<td>",
      "% if (stash('dev_mode')) {",
      "<div>",
      "<form>",
      "</form>",
      "</div>",
      "% } else {",
      "<em>dev</em>",
      "% }",
      "</td>",
      "";

  my $expected = join "\n",
      "<td>",
      "  % if (stash('dev_mode')) {",
      "    <div>",
      "      <form>",
      "      </form>",
      "    </div>",
      "  % } else {",
      "    <em>dev</em>",
      "  % }",
      "</td>",
      "";

  is $pt->tidy( $in ), $expected,
      'html opened under td remains aligned across EP branch';
};

subtest 'top level percent sub block stays visually coherent' => sub {
  my $in = join "\n",
      "% my \$label_for = sub {",
      "  % my (\$k) = \@_;",
      "  % return \$k || 'UNKNOWN';",
      "% };",
      "";

  my $expected = join "\n",
      "% my \$label_for = sub {",
      "  % my (\$k) = \@_;",
      "  % return \$k || 'UNKNOWN';",
      "% };",
      "";

  is $pt->tidy( $in ), $expected,
      'top level percent sub block remains coherent';
};

subtest 'void elements do not increase indentation' => sub {
  my $in = "<div>\n<img src=\"x.png\">\n<p>\nHello\n</p>\n</div>\n";

  my $expected =
      "<div>\n  <img src=\"x.png\">\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'void tags do not shift indentation depth';
};

############
subtest 'columns splits long html comment into multiple comment lines at safe
punctuation' => sub {
  my $pt = Mojo::PrettyTidy->new(
                                  indent_width => 2,
                                  tab_width    => 2,
                                  columns      => 50, );

  my $comment =
        '<!-- canonical field name is ih; keep hash too until '
      . '/qbt/add_one is fully migrated -->';

  my $in = join "\n", '<div>', "  $comment", '</div>', '';

  my $expected = join "\n",
      '<div>',
      '  <!-- canonical field name is ih; -->',
      '  <!-- keep hash too until /qbt/add_one is fully migrated -->',
      '</div>',
      '';

  is $pt->tidy( $in ), $expected,
'long html comment splits into multiple comment lines at safe punctuation';
};

subtest 'single-line button expands into block form by default' => sub {
  my $in = join "\n",
      "<div>",
      '<button type="button" '
      . 'onclick="qbtlOpenViewModal(\'<%= $t->{ih} %>\')">View</button>',
      "</div>",
      "";

  my $expected = join "\n",
      "<div>",
      '  <button type="button"',
      '    onclick="qbtlOpenViewModal(\'<%= $t->{ih} %>\')">',
      "    View",
      "  </button>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected, 'button expands into block form';
};

subtest 'single-line input expands into vertical attribute form by default' =>
    sub {
  my $in = join "\n",
      "<form>",
      "<input type=\"hidden\" name=\"ih\" value=\"<%= \$ih %>\">",
      "</form>",
      "";

  my $expected = join "\n",
      "<form>",
      "  <input type=\"hidden\"",
      "    name=\"ih\"",
      "    value=\"<%= \$ih %>\">",
      "</form>",
      "";

  is $pt->tidy( $in ), $expected, 'input expands into vertical attribute form';
    };

subtest 'form with child content uses vertical attribute form by default' =>
    sub {
  my $in = join "\n",
      "<div>",
      '<form method="post" action="/qbt/add_one">',
      '<input type="hidden" name="ih" value="<%= $ih %>">',
      "</form>",
      "</div>",
      "";

  my $expected = join "\n",
      "<div>",
      '  <form method="post"',
      '      action="/qbt/add_one">',
      '    <input type="hidden"',
      '      name="ih"',
      '      value="<%= $ih %>">',
      "  </form>",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'form opening tag expands and child content stays readable';
    };

subtest 'preferred form input and button layout uses hanging attribute
    style' => sub {
  my $in = join "\n",
      '<form method="get" action="/qbt/view" '
      . 'target="_blank" style="display:inline; margin:0;">',
      '<input type="hidden" ' . 'name="ih" value="<%= $t->{ih} %>">',
      '<input type="hidden" '
      . 'name="return_to" value="<%= url_for->to_string %>">',
      '<button type="button" '
      . 'onclick="qbtlOpenViewModal(\'<%= $t->{ih} %>\')">View</button>',
      '</form>',
      '';

  my $expected = join "\n",
      '<form method="get"',
      '    action="/qbt/view"',
      '    target="_blank"',
      '    style="display:inline; margin:0;">',
      '  <input type="hidden"',
      '    name="ih"',
      '    value="<%= $t->{ih} %>">',
      '  <input type="hidden"',
      '    name="return_to"',
      '    value="<%= url_for->to_string %>">',
      '  <button type="button"',
      '    onclick="qbtlOpenViewModal(\'<%= $t->{ih} %>\')">',
      '    View',
      '  </button>',
      '</form>',
      '';

  is $pt->tidy( $in ), $expected,
      'preferred elements use hanging attribute layout';
};

subtest 'multiline inline style body hangs deeper than following child tag' =>
    sub {
  my $in = join "\n",
      "<div>",
      '  <div style="',
      'display:flex;',
      'gap:8px;',
      'flex:0 0 auto;',
      'align-items:center;">',
      '  <form id="vmAddForm" method="post" action="/qbt/add_one"'
      . '  style="margin:0;">', '  </form>', '</div>', '';

  my $expected = join "\n",
      "<div>",
      '  <div style="',
      '      display:flex;',
      '      gap:8px;',
      '      flex:0 0 auto;',
      '      align-items:center;">',
      '    <form id="vmAddForm"',
      '        method="post"',
      '        action="/qbt/add_one"',
      '        style="margin:0;">',
      '    </form>',
      '  </div>',
      '';

  is $pt->tidy( $in ), $expected,
      'style body hangs deeper than following child tag';
    };
############

done_testing;
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
###
