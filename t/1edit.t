#!/usr/bin/perl

use Test::More qw(no_plan);
use strict;
BEGIN {
use_ok 'SVN::Core';
use_ok 'SVN::Repos';
use_ok 'SVN::Fs';
use_ok 'SVN::Simple::Edit';
}

local $/;

my $repospath = "/tmp/svn-$$";

my $repos;

ok($repos = SVN::Repos::create("$repospath", undef, undef, undef, undef),
   "create repository at $repospath");

my $fs = $repos->fs;

sub committed {
    diag "committed ".join(',',@_);
}


my $edit;
sub new_edit {
  $edit = SVN::Simple::Edit->
    new(_editor => [SVN::Repos::get_commit_editor
		    ($repos, "file://$repospath",
		     '/', 'root', 'FOO', \&committed)],
	pool => SVN::Pool->new,
	missing_handler => sub {
	    my ($edit, $path) = @_;
	    diag "build missing directory for $path";
	    $edit->add_directory ($path);
	});
}

$edit = new_edit;
$edit->open_root(0);

$edit->add_file ('trunk/deep/more/gfilea');
$edit->add_file ('trunk/deep2/more/gfileb');

$edit->add_file ('filea');

my $text = "FILEA CONTENT";
$edit->modify_file ('filea', $text);


$edit->add_file ('fileb');
open my $fh, $0;
$edit->modify_file ('fileb', <$fh>);

$edit->close_edit();

cmp_ok($fs->youngest_rev, '==', 1);

my $filea = SVN::Fs::file_contents($fs->revision_root (1), 'filea');
is(<$filea>, $text, "content from string verified");
my $fileb = SVN::Fs::file_contents($fs->revision_root (1), 'fileb');
seek $fh, 0, 0;
is(<$fileb>, <$fh>, "content from stream verified");

$edit = new_edit;
$edit->open_root (1);

$edit->modify_file($edit->open_file ('fileb'), 'foo');

$edit->close_edit;

END {
diag "cleanup";
print `svn log -v file://$repospath`;
`rm -rf $repospath`;
}
