#!/usr/bin/perl
use ExtUtils::MakeMaker;

my $required_svn = '0.31.0';

WriteMakefile(
    AUTHOR              => 'Chia-liang Kao (clkao@clkao.org)',
    ABSTRACT            => 'Simple interface to SVN::Delta::Editor',
    NAME                => 'SVN::Simple::Edit',
    VERSION_FROM        => 'lib/SVN/Simple/Edit.pm',
    DISTNAME            => 'SVN-Simple',
    PREREQ_PM           => {
        'SVN::Core'   => $required_svn,
    },
    dist                => {
        COMPRESS        => 'gzip -9',
        SUFFIX          => '.gz',
    },
);

die "SVN::Core $required_svn must be manually installed"
    unless eval {require SVN::Core} && $SVN::Core::VERSION >= $required_svn;
