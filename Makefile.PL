use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tie::Util',
    AUTHOR              => 'Father Chrysostomos <sprout & cpan . org>',
    VERSION_FROM        => 'lib/Tie/Util.pm',
    ABSTRACT_FROM       => 'lib/Tie/Util.pm',
    PL_FILES            => {},
    PREREQ_PM => {
         B             => 0,
         constant      => 0,
         Exporter      => 5.57,
        'Scalar::Util' => 0,
        'Test::More'   => 0,
    },
    dist               => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean              => { FILES => 'Tie-Util-*' },
);
