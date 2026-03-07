use 5.40.0;
use common::sense;

use ExtUtils::MakeMaker;

WriteMakefile(
   NAME         => 'Mojo::PrettyTidy',
   VERSION_FROM => 'lib/Mojo/PrettyTidy.pm',
   ABSTRACT     => 'Conservative tidy tool for Mojolicious .html.ep templates',
   AUTHOR       => 'Harry Bennett',
   LICENSE      => 'perl',
   EXE_FILES    => ['script/mojo-prettytidy'],
   PREREQ_PM    => {
                 'Getopt::Long' => 0,
                 'Pod::Usage'   => 0,
                 'Test::More'   => 0,
   },
   META_MERGE => {
     resources => {repository => 'https://github.com/Harryb382003/PrettyTidy',},
   }, );
