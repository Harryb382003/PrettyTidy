use v5.40.0;
use common::sense;

use ExtUtils::MakeMaker;

WriteMakefile(
   NAME         => 'Mojo::PrettyTidy',
   VERSION_FROM => 'lib/Mojo/PrettyTidy.pm',
   ABSTRACT     => 'Conservative tidy tool for Mojolicious .html.ep templates',
   AUTHOR       => 'Harry Bennett',
   LICENSE      => 'perl',
   MIN_PERL_VERSION => '5.040000',
   EXE_FILES        => ['script/mojo-prettytidy'],
   PREREQ_PM        => {
                 'common::sense' => 0,
                 'Getopt::Long'  => 0,
                 'Pod::Usage'    => 0,
   },
   META_MERGE => {
     resources => {repository => 'https://github.com/Harryb382003/PrettyTidy',},
   }, );
