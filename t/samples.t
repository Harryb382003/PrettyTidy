use v5.40;
use common::sense;

use Test::More;
use Mojo::PrettyTidy;
use File::Spec;

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

pass 'sample-driven smoke test completed';

done_testing;
