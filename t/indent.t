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

subtest 'attribute-level EP line keeps structure but inherits outer indent' =>
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
      "    function x() {",
      "    return 1;",
      "    }",
      "    </script>",
      "  % }",
      "</div>",
      "";

  is $pt->tidy( $in ), $expected,
      'closing div after script and EP block stays aligned';
};

subtest 'doctype line is kept at current level' => sub {
  my $in = "<!DOCTYPE html>\n<div>\n<p>\nHello\n</p>\n</div>\n";

  my $expected = "<!DOCTYPE html>\n<div>\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'doctype line stays neutral and does not affect nesting';
};

subtest 'ep wrapper keeps opening and closing html aligned' => sub {
  my $in = join "\n", "% if (\$show) {", "<div>", "</div>", "% }", "";

  my $expected = join "\n", "% if (\$show) {", "  <div>", "  </div>", "% }", "";

  is $pt->tidy( $in ), $expected,
      'opening and closing tags stay aligned inside EP block';
};

subtest 'ep wrapper with inner branch keeps plain text and links aligned' =>
    sub {
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
      "% for my \$t (\@\$sample) {",
      "  <tr>",
      "    <td><%= \$t->{name} %></td>",
      "    <td><code><%= \$t->{ih} %></code></td>",
      "    <td>",
      "    % if (stash('dev_mode')) {",
      "      <div class=\"qbtl-actions\">",
      "        <form method=\"post\" action=\"/qbt/add_one\">",
"          <input type=\"hidden\" name=\"ih\" value=\"<%= \$t->{ih} %>\">",
      "          <button type=\"submit\">Add</button>",
      "        </form>",
      "      </div>",
      "    % } else {",
      "      <em>dev</em>",
      "    % }",
      "    </td>",
      "  </tr>",
      "% }",
      "";

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
"<div>\n<%= \$title %>\n  <!-- note -->\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'comment line indents normally while EP line stays untouched';
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

  my $expected = "<div>\n<% if (\$ok) { %>\n  <p>Hello</p>\n<% } %>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'mixed EP block lines are not reindented';
};

subtest 'mixed inline children align under parent' => sub {
  my $in = join "\n",
      "<div>",
"<div style=\"margin-top:12px; border-top:1px solid #2a2a2a; padding-top:10px;\">",
"<div id=\"vmCount\" style=\"font-weight:700; margin-bottom:6px;\">Contents</div>",
"<ul id=\"vmList\" style=\"margin:0; padding-left:18px; line-height:1.35;\"></ul>",
      "</div>",
      "</div>",
      "";

  my $expected = join "\n",
      "<div>",
"  <div style=\"margin-top:12px; border-top:1px solid #2a2a2a; padding-top:10px;\">",
"    <div id=\"vmCount\" style=\"font-weight:700; margin-bottom:6px;\">Contents</div>",
"    <ul id=\"vmList\" style=\"margin:0; padding-left:18px; line-height:1.35;\"></ul>",
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
  my $in = "<div>\n<%= \$title %>\n<!--\nnote\n-->\n<p>\nHello\n</p>\n</div>\n";

  my $expected =
"<div>\n<%= \$title %>\n  <!--\n  note\n  -->\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'multiline comment block indents normally while EP line stays untouched';
};

subtest 'multiline inline style indents cleanly' => sub {
  my $in =
"<div style=\"\nposition:absolute;\ntop:6%;\nleft:50%;\ntransform:translateX(-50%);\n\">\n</div>\n";

  my $expected =
"<div style=\"\n  position:absolute;\n  top:6%;\n  left:50%;\n  transform:translateX(-50%);\n\">\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'multiline inline style declarations are indented';
};

subtest 'nested multiline inline style follows html indentation' => sub {
  my $in =
"<div>\n<div style=\"\nposition:absolute;\ntop:6%;\nleft:50%;\n\">\n</div>\n</div>\n";

  my $expected =
"<div>\n  <div style=\"\n    position:absolute;\n    top:6%;\n    left:50%;\n  \">\n  </div>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'multiline inline style declarations follow surrounding html indentation';
};

subtest 'multiline inline style with EP is left alone' => sub {
  my $in =
"<div style=\"\ncolor:<%= \$color %>;\nbackground:#151515;\n\">\n</div>\n";

  my $expected =
"<div style=\"\ncolor:<%= \$color %>;\nbackground:#151515;\n\">\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'multiline inline style attribute containing EP is not reformatted';
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
      "      function x() {",
      "      return 1;",
      "      }",
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

  my $expected = "<div>\n<%= \$title %>\n  <p>\n    Hello\n  </p>\n</div>\n";

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
      "<div>\n<script>\nif (x < 10) {\nconsole.log(x);\n}\n</script>\n</div>\n";

  my $expected =
"<div>\n  <script>\n  if (x < 10) {\n  console.log(x);\n  }\n  </script>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'script wrapper lines indent, script body is left alone';
};

subtest 'script block near EP lines keeps EP safe' => sub {
  my $in =
"<div>\n<%= \$title %>\n<script>\nif (x < 10) {\nconsole.log(x);\n}\n</script>\n</div>\n";

  my $expected =
"<div>\n<%= \$title %>\n  <script>\n  if (x < 10) {\n  console.log(x);\n  }\n  </script>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'script block indents normally while EP line stays untouched';
};

subtest 'separator text line inside EP block is indented as plain text' => sub {
  my $in = join "\n", "% if (\$page > 1) {", "|", "% }", "";

  my $expected = join "\n", "% if (\$page > 1) {", "  |", "% }", "";

  is $pt->tidy( $in ), $expected,
      'plain separator text follows EP indentation level';
};

subtest 'script block with inline attributes is handled safely' => sub {
  my $in =
"<div>\n<script type=\"text/javascript\">\nif (x < 10) {\nconsole.log(x);\n}\n</script>\n</div>\n";

  my $expected =
"<div>\n  <script type=\"text/javascript\">\n  if (x < 10) {\n  console.log(x);\n  }\n  </script>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'script block with attributes is treated as a protected block';
};

subtest 'style block indented, interior lines left structurally alone' => sub {
  my $in = "<div>\n<style>\n.foo {\ncolor: red;\n}\n</style>\n</div>\n";

  my $expected =
      "<div>\n  <style>\n  .foo {\n  color: red;\n  }\n  </style>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'style wrapper lines indent, style body is left alone';
};

subtest 'style block near EP lines keeps EP safe' => sub {
  my $in =
"<div>\n<%= \$title %>\n<style>\n.foo {\ncolor: red;\n}\n</style>\n</div>\n";

  my $expected =
"<div>\n<%= \$title %>\n  <style>\n  .foo {\n  color: red;\n  }\n  </style>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'style block indents normally while EP line stays untouched';
};

subtest 'style block with inline attributes is handled safely' => sub {
  my $in =
"<div>\n<style media=\"screen\">\n.foo {\ncolor: red;\n}\n</style>\n</div>\n";

  my $expected =
"<div>\n  <style media=\"screen\">\n  .foo {\n  color: red;\n  }\n  </style>\n</div>\n";

  is $pt->tidy( $in ), $expected,
      'style block with attributes is treated as a protected block';
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

subtest 'void elements do not increase indentation' => sub {
  my $in = "<div>\n<img src=\"x.png\">\n<p>\nHello\n</p>\n</div>\n";

  my $expected =
      "<div>\n  <img src=\"x.png\">\n  <p>\n    Hello\n  </p>\n</div>\n";

  is $pt->tidy( $in ), $expected, 'void tags do not shift indentation depth';
};

############

############

done_testing;
