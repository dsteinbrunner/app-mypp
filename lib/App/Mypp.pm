package App::Mypp;

=head1 NAME

App::Mypp - Maintain Your Perl Project

=head1 VERSION

0.01

=head1 DESCRIPTION

mypp is a result of me getting tired of doing the same stuff - or
rather forgetting to do the same stuff for each of my perl projects.
mypp does not feature the same things as Dist::Zilla, but I would
like to think of mypp VS dzil as CPAN  vs cpanm - or at least that
is what I'm aming for. (!) What I don't want to do, is to configure
anything, so 1) it just works 2) it might not work as you want it to.

=head1 SYNOPSIS

 Usage mypp [option]

 -update
  * Update version information in main module
  * Create/update t/00-load.t and t/99-pod*t
  * Create/update README

 -build
  * Same as -update
  * Update Changes with release date
  * Create MANIFEST* and META.yml
  * Tag and commit the changes (locally)
  * Build a distribution (.tar.gz)

 -share
  * Push commit and tag to "origin"
  * Upload the disted file to CPAN

 -test
  * Create/update t/00-load.t and t/99-pod*t
  * Test the project

 -clean
  * Remove files and directories which should not be included
    in the project repo

 -makefile
  * Create a Makefile.PL from plain guesswork

 -man
  * Display manual for mypp

=head1 SAMPLE CONFIG FILE

 ---
 # Default to a converted version of top_module
 name: Foo-Bar
 
 # Default to a converted version of the project folder
 # Example: ./foo-bar/lib/Foo/Bar.pm, were "foo-bar" is the
 # project folder.
 top_module: lib/Foo/Bar.pm 
 
 # Default to a converted version of top_module.
 top_module_name: Foo::Bar 
 
 # Default to CPAN::Uploader. Can also be set through
 # DPERL_SHARE_MODULE environment variable.
 share_extension: AnyModuleName
 
 # Not in use if share_extension == CPAN::Uploader. Usage:
 # share_extension->upload_file($dist_file, share_params);
 share_params: { answer: 42 }

All config params are optional, since mypp will probably figure out the
information for you.

=head1 SHARING THE MODULE

By default the L<CPAN::Uploader> module is used to upload the module to CPAN.
This module will use the information from C<$HOME/.pause> to find login
information:

 user your_pause_username
 password your_secret_pause_password

It will also use git to push changes and tag a new release:

 git commit -a -m "$message_from_changes_file"
 git tag "$latest_version_in_changes_file"
 git push origin $current_branch
 git push --tags origin

The commit and tag is done when on C<-dist>, while pushing the changes to
origin is done on C<-share>.

=head1 Changes

The expected format in C<Changes> is:

 Some random header, for Example:
 Revision history for Foo-Bar

 0.02
  * Fix something
  * Add something else

 0.01 Tue Apr 20 19:34:15 CEST 2010
  * First release
  * Add some feature

C<mypp> will automatically add the date before creating a dist.

=cut

use strict;
use warnings;
use Cwd;
use File::Basename;
use File::Find;
use YAML::Tiny;

our $VERSION = '0.01';
our $SILENT = $ENV{'SILENT'} || 0;
our $CHANGES_FILENAME = 'Changes';
our $VERSION_RE = qr/\d+ \. [\d_]+/x;

sub _from_config ($&) {
    my($name, $sub) = @_;

    no strict 'refs';

    *$name = sub {
        my $self = shift;
        return $self->{$name} ||= $self->config->{$name} || $self->$sub(@_);
    };
}

sub _attr ($&) {
    my($name, $sub) = @_;

    no strict 'refs';

    *$name = sub {
        my $self = shift;
        return $self->{$name} ||= $self->$sub(@_);
    };
}

=head1 ATTRIBUTES

=head2 config

 $hash = $self->config;

Holds the config from C<mypp.yml> or C<MYPP_CONFIG> environment variable.

=cut

_attr config => sub {
    my $self = shift;
    my $config = YAML::Tiny->read( $ENV{'MYPP_CONFIG'} || 'mypp.yml' );

    return $config->[0] if($config and $config->[0]);
    return {};
};

=head2 name

Holds the project name. The project name is extracted from the
L</top_module>, unless set in config file. Example: C<foo-bar>.

=cut

_from_config name => sub {
    my $self = shift;
    my $name;

    $name = join '-', split '/', $self->top_module;
    $name =~ s,^.?lib-,,;
    $name =~ s,\.pm$,,;

    return $name;
};

=head2 top_module

Holds the top module location. This path is extracted from either
C<name> in config file or the basename of the project. Example value:
C<lib/Foo/Bar.pm>.

The project might look like this:

 ./foo-bar/lib/Foo/Bar.pm

Where "foo-bar" is the basename.

=cut

_from_config top_module => sub {
    my $self = shift;
    my $name = $self->config->{'name'} || basename getcwd;
    my @path = split /-/, $name;
    my $path = 'lib';
    my $file;

    $path[-1] .= '.pm';

    for my $p (@path) {
        opendir my $DH, $path or die "Cannot find top module from project name '$name': $!\n";
        for my $f (readdir $DH) {
            if(lc $f eq lc $p) {
                $path = "$path/$f";
                last;
            }
        }
    }
    
    unless(-f $path) {
        die "Cannot find top module from project name '$name': $path is not a plain file\n";
    }

    return $path;
};

=head2 top_module_name

Returns the top module name, extracted from L</top_module>. Example value:
C<Foo::Bar>.

=cut

_from_config top_module_name => sub {
    my $self = shift;
    return $self->_filename_to_module($self->top_module);
};

=head2 changes

Holds the latest information from C<Changes>. Example:

 {
   text => qq(0.03 .... \n * Something has changed),
   version => 0.03,
 }

=cut

_attr changes => sub {
    my $self = shift;
    my($text, $version);

    open my $CHANGES, '<', $CHANGES_FILENAME or die "Read '$CHANGES_FILENAME': $!\n";

    while(<$CHANGES>) {
        if($text) {
            if(/^$/) {
                last;
            }
            else {
                $text .= $_;
            }
        }
        elsif(/^($VERSION_RE)/) {
            $version = $1;
            $text = $_;
        }
    }

    unless($text and $version) {
        die "Could not find commit message nor version info from $CHANGES_FILENAME\n";
    }

    return {
        text => $text,
        version => $version,
    };
};

=head1 METHODS

=head2 new

 $self = App::Mypp->new;

=cut

sub new {
    return bless {}, __PACKAGE__;
}

=head2 timestamp_to_changes

Will insert a timestamp in Changes on the first line looking like this:

 ^\d+\.[\d_]+\s*$

=cut

sub timestamp_to_changes {
    my $self = shift;
    my $date = qx/date/; # ?!?
    my($changes, $pm);

    chomp $date;

    open my $CHANGES, '+<', $CHANGES_FILENAME or die "Read/write '$CHANGES_FILENAME': $!\n";
    { local $/; $changes = <$CHANGES> };

    if($changes =~ s/\n($VERSION_RE)\s*$/{ sprintf "\n%-7s  %s", $1, $date }/em) {
        seek $CHANGES, 0, 0;
        print $CHANGES $changes;
        print "Add timestamp '$date' to $CHANGES_FILENAME\n" unless $SILENT;
        return 1;
    }

    die "Unable to update $CHANGES_FILENAME with timestamp\n";
}

=head2 update_version_info

Will update version in top module, with the latest version from C<Changes>.

=cut

sub update_version_info {
    my $self = shift;
    my $top_module = $self->top_module;
    my $version = $self->changes->{'version'};
    my $top_module_text;

    open my $MODULE, '+<', $top_module or die "Read/write '$top_module': $!\n";
    { local $/; $top_module_text = <$MODULE> };
    $top_module_text =~ s/=head1 VERSION.*?\n=/=head1 VERSION\n\n$version\n\n=/s;
    $top_module_text =~ s/^((?:our)?\s*\$VERSION)\s*=.*$/$1 = '$version';/m;

    seek $MODULE, 0, 0;
    print $MODULE $top_module_text;

    print "Update version in '$top_module' to $version\n" unless $SILENT;

    return 1;
}

=head2 generate_readme

Will generate a C<README> file from the plain old documentation in top
module.

=cut

sub generate_readme {
    my $self = shift;
    return $self->_vsystem(
        sprintf '%s %s > %s', 'perldoc -tT', $self->top_module, 'README'
    ) ? 0 : 1;
}

=head2 clean

Will remove all files which should not be part of your repo.

=cut

sub clean {
    my $self = shift;
    my $name = $self->name;
    $self->vsystem('make clean 2>/dev/null');
    $self->vsystem(sprintf 'rm -r %s 2>/dev/null', join(' ',
        "$name*",
        qw(
            blib/
            inc/
            Makefile
            Makefile.old
            MANIFEST*
            META.yml
        ),
    ));

    return 1;
}

sub _vsystem {
    shift; # shift off class/object
    print "\$ @_\n" unless $SILENT;
    system @_;
}

sub _filename_to_module {
    local $_ = $_[1];
    s,\.pm,,;
    s,^/?lib/,,g;
    s,/,::,g;
    return $_;
}

=head1 SEE ALSO

L<App::Cpanminus>,
L<Dist::Zilla>,
L<http://jhthorsen.github.com/app-mypp>.

=head1 BUGS

Report bugs and issues at L<http://github.com/jhthorsen/snippets/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Jan Henning Thorsen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. 

=head1 AUTHOR

Jan Henning Thorsen, C<jhthorsen at cpan.org>

=cut

1;
