package SVN::Simple::Edit;
@ISA = qw(SVN::Delta::Editor);
$VERSION = '0.21';
use strict;
use SVN::Core '0.31';
use SVN::Delta;

=head1 NAME

SVN::Simple::Edit - A simple interface for driving svn delta editors

=head1 SYNOPSIS

my $edit = SVN::Simple::Edit->new
    (_editor => SVN::Repos::get_commit_editor($repos, "file://$repospath",
			              '/', 'root', 'FOO', \&committed));

$edit->open_root(0);

$edit->add_directory ('trunk');

$edit->add_file ('trunk/filea');

$edit->copy_directory ('branches/a, trunk, 0);

$edit->modify_file ("trunk/fileb", "content", $checksum);

=head1 DESCRIPTION

SVN::Simple::Edit wraps the subversion delta editor with a perl
friendly interface and then you could easily drive it for describing
changes to a tree. A common usage is to wrap the commit editor, so
you could make committs to a subversion tree easily.

This also means you can not supply the C<$edit> object as an
delta_editor to other API. and that's why it's called Edit instead of
Editor. see L<SVN::Simple::Editor> for simple interface implementing a
delta editor.

=cut

require File::Spec::Unix;

sub splitpath { File::Spec::Unix->splitpath(@_) };
sub canonpath { File::Spec::Unix->canonpath(@_) };

sub build_missing {
    my ($self, $path) = @_;
    $self->add_directory ($path);
}

sub open_missing {
    my ($self, $path) = @_;
    $self->open_directory ($path);
}

sub check_missing {
    my ($root) = @_;
    return sub {
	my ($self, $path) = @_;
	$root ||= $self->{root};
	$root->check_path (($self->{base_path} || '')."/$path") == $SVN::Node::none ?
	    $self->add_directory ($path) : $self->open_directory($path);
    }
}

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{BATON} = {};
    $self->{missing_handler} ||= \&build_missing;
    return $self;
}

sub set_target_revision {
    my ($self, $target_revision) = @_;
    $self->SUPER::set_target_revision ($target_revision);
}

sub _rev_from_root {
    my ($self, $path) = @_;
    $path = "/$path" if $path;
    $path ||= '';
    return $self->{root}->node_created_rev($self->{base_path}.$path);
}

sub open_root {
    my ($self, $base_revision) = @_;
    $base_revision ||= $self->_rev_from_root ()	if $self->{root};
    $self->{BASE} = $base_revision;
    $self->{BATON}{''} = $self->SUPER::open_root
	($base_revision, ${$self->{pool}});
}

sub find_pbaton {
    my ($self, $path, $missing_handler) = @_;
    use Carp;
    return $self->{BATON}{''} unless $path;
    my (undef, $dir, undef) = splitpath($path);
    $dir = canonpath ($dir);

    return $self->{BATON}{$dir} if exists $self->{BATON}{$dir};

    $missing_handler ||= $self->{missing_handler};
    die "unable to get baton for directory $dir"
	unless $missing_handler;

    my $pbaton = &$missing_handler ($self, $dir);

    return $pbaton;
}

sub open_directory {
    my ($self, $path, $pbaton) = @_;
    $path =~ s|^/||;
    $pbaton ||= $self->find_pbaton ($path);
    my $base_revision = $self->_rev_from_root ($path) if $self->{root};
    $base_revision ||= $self->{BASE};
    $self->{BATON}{$path} = $self->SUPER::open_directory ($path, $pbaton,
							  $base_revision,
							  $self->{pool});
}

sub add_directory {
    my ($self, $path, $pbaton) = @_;
    $path =~ s|^/||;
    $pbaton ||= $self->find_pbaton ($path);
    $self->{BATON}{$path} = $self->SUPER::add_directory ($path, $pbaton, undef,
							 -1, $self->{pool});
}

sub copy_directory {
    my ($self, $path, $from, $fromrev, $pbaton) = @_;
    $path =~ s|^/||;
    $pbaton ||= $self->find_pbaton ($path);
    $self->{BATON}{$path} = $self->SUPER::add_directory ($path, $pbaton, $from,
							 $fromrev,
							 $self->{pool});
}

sub open_file {
    my ($self, $path, $pbaton) = @_;
    $path =~ s|^/||;
    $pbaton ||= $self->find_pbaton ($path);
    my $base_revision = $self->_rev_from_root ($path) if $self->{root};
    $base_revision ||= $self->{BASE};
    $self->{BATON}{$path} = $self->SUPER::open_file ($path, $pbaton,
						     $base_revision,
						     $self->{pool});
}

sub add_file {
    my ($self, $path, $pbaton) = @_;
    $path =~ s|^/||;
    $pbaton ||= $self->find_pbaton ($path);
    $self->{BATON}{$path} = $self->SUPER::add_file ($path, $pbaton, undef, -1,
						    $self->{pool});
}

sub copy_file {
    my ($self, $path, $from, $fromrev, $pbaton) = @_;
    $path =~ s|^/||;
    $pbaton ||= $self->find_pbaton ($path);
    $self->{BATON}{$path} = $self->SUPER::add_file ($path, $pbaton, $from,
						    $fromrev, $self->{pool});
}

sub modify_file {
    my ($self, $path, $content, $targetchecksum) = @_;
    $path =~ s|^/|| unless ref($path);
    my $baton = ref($path) ? $path :
	($self->{BATON}{$path} || $self->open_file ($path));
    my $ret = $self->apply_textdelta ($baton, undef, $self->{pool});

    if (ref($content) && $content->isa ('GLOB')) {
	my $md5 = SVN::TxDelta::send_stream ($content,
					     @$ret,
					     $self->{pool});
	die "checksum mistach ($md5) vs ($targetchecksum)" if $targetchecksum
	    && $targetchecksum ne $md5;
    }
    else {
	SVN::_Delta::svn_txdelta_send_string ($content, @$ret, $self->{pool});
    }
}

sub delete_entry {
    my ($self, $path, $pbaton) = @_;
    $path =~ s|^/||;
    $pbaton ||= $self->find_pbaton ($path, \&open_missing);
    my $base_revision = $self->_rev_from_root ($path) if $self->{root};
    $base_revision ||= $self->{BASE};
    $self->SUPER::delete_entry ($path, $base_revision, $pbaton, $self->{pool});
}

sub change_file_prop {
    my ($self, $path, $key, $value) = @_;
    $path =~ s|^/|| unless ref($path);
    my $baton = ref($path) ? $path :
	($self->{BATON}{$path} || $self->open_file ($path));
    $self->SUPER::change_file_prop ($baton, $key, $value, $self->{pool});
}

sub change_dir_prop {
    my ($self, $path, $key, $value) = @_;
    $path =~ s|^/|| unless ref($path);
    my $baton = ref($path) ? $path :
	($self->{BATON}{$path} || $self->open_directory ($path));
    $self->SUPER::change_dir_prop ($baton, $key, $value, $self->{pool});
}

sub close_file {
    my ($self, $path, $checksum) = @_;
    my $baton = $self->{BATON}{$path} or die "not opened";
    delete $self->{BATON}{$path};
    $self->SUPER::close_file ($baton, $checksum, $self->{pool});
}

sub close_directory {
    my ($self, $path) = @_;
    my $baton = $self->{BATON}{$path} or die "not opened";
    delete $self->{BATON}{$path};
    $self->SUPER::close_directory ($baton, $self->{pool});
}

=for todo

close all directories and files gracefully upon close_edit and abort_edit

=cut

sub close_edit {
    my ($self) = @_;

    $self->SUPER::close_edit ($self->{pool});
}

sub abort_edit {
    my ($self) = @_;

    $self->SUPER::abort_edit ($self->{pool});
}

=head1 AUTHORS

Chia-liang Kao E<lt>clkao@clkao.orgE<gt>

=head1 COPYRIGHT

Copyright 2003 by Chia-liang Kao E<lt>clkao@clkao.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
1;
