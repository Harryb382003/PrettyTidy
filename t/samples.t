use v5.40.0;
use common::sense;
use feature 'signatures';

use Test::More;
use File::Spec;

use lib 'lib';
use Mojo::PrettyTidy;

my $pt = Mojo::PrettyTidy->new;

my $sample = File::Spec->catfile( qw(share samples sample_1.html.ep) );

ok -e $sample, 'sample file exists';

open my $fh, '<', $sample or die "Cannot open '$sample' for reading: $!";
local $/;
my $input = <$fh>;
close $fh;

ok defined $input,   'sample file was read';
ok length( $input ), 'sample file is not empty';

my $output = $pt->tidy( $input );

ok defined $output,   'tidy returned output';
ok length( $output ), 'output is not empty';
like $output, qr/\n\z/, 'output ends with a newline';

my $in_pct_lines  = () = $input  =~ /^%/mg;
my $out_pct_lines = () = $output =~ /^%/mg;
is $out_pct_lines, $in_pct_lines, 'percent directive line count preserved';

my $in_ep_tags  = () = $input  =~ /<%[=%]?/g;
my $out_ep_tags = () = $output =~ /<%[=%]?/g;
is $out_ep_tags, $in_ep_tags, 'EP tag count preserved';

my $in_lines_with_ep  = () = $input  =~ /^.*<%.*$/mg;
my $out_lines_with_ep = () = $output =~ /^.*<%.*$/mg;
is $out_lines_with_ep, $in_lines_with_ep,
    'lines containing EP markers are preserved in count';

if ( $input =~ /<%=/ ) {
  like $output, qr/<%=/, 'expression tag survives';
}

if ( $input =~ /<%==/ ) {
  like $output, qr/<%==/, 'escaped expression tags survive';
}

if ( $input =~ /<%/ ) {
  like $output, qr/<%/, 'EP tag survives';
}

pass 'sample-driven smoke test completed';

done_testing;
