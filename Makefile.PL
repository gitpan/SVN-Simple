#!/usr/bin/perl
use ExtUtils::MakeMaker;

WriteMakefile(
    AUTHOR              => 'Chia-liang Kao (clkao@clkao.org)',
    ABSTRACT            => 'Simple interface to SVN::Delta::Editor',
    NAME                => 'SVN::Simple::Edit',
    VERSION_FROM        => 'lib/SVN/Simple/Edit.pm',
    DISTNAME            => 'SVN-Simple',
    PREREQ_PM           => {
        'SVN::Core'   => '0.31',
    },
    dist                => {
        COMPRESS        => 'gzip -9',
        SUFFIX          => '.gz',
    },
);

