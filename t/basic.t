use v5.40.0;
use common::sense;
use feature 'signatures';

use Test::More;
use lib 'lib';
use Mojo::PrettyTidy;

my $pt = Mojo::PrettyTidy->new;

is( $pt->tidy( "abc  \nxyz\t \n" ),
    "abc\nxyz\n", 'removes trailing horizontal whitespace', );

is( $pt->tidy( "abc\r\nxyz\r\n" ), "abc\nxyz\n", 'normalizes CRLF to LF', );

is( $pt->tidy( "abc" ), "abc\n", 'ensures trailing newline', );

ok( $pt->check( "abc\n" ), 'check returns true when unchanged' );
ok( !$pt->check( "abc  \n" ),
    'check returns false when changes would be made' );

done_testing;
