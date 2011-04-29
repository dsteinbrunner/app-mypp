package App::Mypp;

=head1 NAME

App::Mypp - Maintain Your Perl Project

=head1 VERSION

0.11

=head1 DESCRIPTION

mypp is a result of me getting tired of doing the same stuff - or
rather forgetting to do the same stuff - for each of my Perl projects.
mypp does not feature the same things as L<Dist::Zilla>, but I would
like to think of mypp vs dzil as cpanm vs CPAN - or at least that
is what I'm aiming for. (!) What I don't want to do is configure
anything, so 1) it should just work 2) it might not work as you want it to.

Want to try it out? Run the line below in your favourite terminal:

 wget -q http://github.com/jhthorsen/app-mypp/raw/master/script/mypp-packed -O - | perl -

Running that line will start the experimental code from github - meaning
the latest release. Run at own risk - and don't forget to put your files
under version control first!

=head1 SYNOPSIS

 Usage mypp [option]

 -update
  * Update version information in main module
  * Create/update t/00-load.t and t/00-pod*t
  * Create/update README

 -test
  * Create/update t/00-load.t and t/00-pod*t
  * Test the project

 -build
  * Same as -update
  * Update Changes with release date
  * Create MANIFEST* and META.yml
  * Tag and commit the changes (locally)
  * Build a distribution (.tar.gz)

 -share
  * Push commit and tag to "origin"
  * Upload the disted file to CPAN

 -clean
  * Remove files and directories which should not be included
    in the project repo

 -makefile
  * Create "Makefile.PL" from plain guesswork

 -changes
  * Create "Changes" from template

 -version
  * Display the version number for for mypp

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
 # MYPP_SHARE_MODULE environment variable.
 share_extension: AnyModuleName
 
 # Not in use if share_extension == CPAN::Uploader. Usage:
 # share_extension->upload_file($dist_file, share_params);
 share_params: [ { answer: 42 } ]

All config params are optional, since mypp tries to figure out the
information for you.

=head1 SHARING THE MODULE

By default the L<CPAN::Uploader> module is used to upload the module to CPAN.
This module uses C<$HOME/.pause> to find login details:

 user your_pause_username
 password your_secret_pause_password

It also uses git to push changes and tag a new release:

 git commit -a -m "$message_from_changes_file"
 git tag "$latest_version_in_changes_file"
 git push origin $current_branch
 git push --tags origin

The commit and tagging is done with C<-dist>, while pushing the changes to
origin is done with C<-share>.

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

C<mypp> automatically adds the date before creating a dist.

=cut

use strict;
use warnings;
use Cwd;
use File::Basename;
use File::Find;

our $VERSION = eval '0.10';
our $SILENT = $ENV{'MYPP_SILENT'} || $ENV{'SILENT'} || 0;
our $MAKEFILE_FILENAME = 'Makefile.PL';
our $CHANGES_FILENAME = 'Changes';
our $PAUSE_FILENAME = $ENV{'HOME'} .'/.pause';
our $VERSION_RE = qr/\d+ \. [\d_]+/x;

open my $OLDOUT, '>&STDOUT';
open my $OLDERR, '>&STDERR';

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
    my $file = $ENV{'MYPP_CONFIG'} || 'mypp.yml';
    my $config;

    return {} unless(-e $file);

    eval "use YAML::Tiny; 1;" or do {
        die <<"ERROR";

YAML::Tiny is not installed, meaning '$file' will not be read.
Use one of the commands below to install it:

\$ aptitude install libyaml-tiny-perl
\$ wget -q http://xrl.us/cpanm -O - | perl - YAML::Tiny

ERROR
    };

    $config = YAML::Tiny->read($file);

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
C<name> in the config file or the basename of the project. Example value:
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

    unless(-e $CHANGES_FILENAME) {
        open my $CHANGES, '>', $CHANGES_FILENAME or die "Write '$CHANGES_FILENAME': $!\n";
        printf $CHANGES "Revision history for %s\n\n0.00\n", $self->name;
        print $CHANGES " " x 7, "* Init repo\n\n";
        $self->_log("Created $CHANGES_FILENAME");
    }

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

=head2 dist_file

Returns the name of the target dist file.

=cut

_attr dist_file => sub {
    my $self = shift;
    return sprintf '%s-%s.tar.gz', $self->name, $self->changes->{'version'};
};

=head2 pause_info

Holds information from C<$HOME/.pause>. See L<CPAN::Uploader> for details.
Example:

 {
   user => 'johndoe',
   password => 's3cret',
 }

=cut

_attr pause_info => sub {
    my $self = shift;
    my $info;

    open my $PAUSE, '<', $PAUSE_FILENAME or die "Read $PAUSE_FILENAME: $!\n";

    while(<$PAUSE>) {
        my($k, $v) = split /\s+/, $_, 2;
        chomp $v;
        $info->{$k} = $v;
    }

    die "'user <name>' is not set in $PAUSE_FILENAME\n" unless $info->{'user'};
    die "'password <mysecret>' is not set in $PAUSE_FILENAME\n" unless $info->{'password'};

    return $info;
};

=head2 share_extension

Holds the classname of the module which should be used for sharing. This
value can either come from the config file or the C<MYPP_SHARE_MODULE> environment
variable, or fallback to L<CPAN::Uploader>.

=cut

_attr share_extension => sub {
    my $self = shift;

    return $ENV{'MYPP_SHARE_MODULE'} if($ENV{'MYPP_SHARE_MODULE'});
    return $self->config->{'share_extension'} if($self->config->{'share_extension'});
    return 'CPAN::Uploader';
};

=head2 share_params

This attribute must hold an array ref, since it is flattened into a list when
used as an argument to L</share_extension>'s C<upload_file()> method.

=cut

_from_config share_params => sub {
    return;
};

=head2 perl5lib

This attribute holds an array-ref of optional perl library search
directories. This attribute is used when setting up C<use lib> in
generated files and will also be unshifted on C<@INC> in L</new()>

NOTE! This was set by C<PERL5LIB> environment variable in prior versions,
but this is now deprecated.

=cut

_attr perl5lib => sub {
    my $self = shift;
    my $inc = $self->config->{'perl5lib'};

    if(!$inc) {
        $inc = [];
    }
    elsif(ref $inc ne 'ARRAY') {
        $inc = [ split /:/, $inc ];
    }

    return $inc;
};

_attr _eval_package_requires => sub {
    eval q(package __EVAL__;
        no warnings "redefine";
        our @REQUIRES;
        sub use { push @REQUIRES, @_ }
        sub require { push @REQUIRES, @_ }
        sub base { push @REQUIRES, @_ }
        sub extends { push @REQUIRES, @_ }
        sub with { push @REQUIRES, @_ }
        1;
    ) or die $@;

    return \@__EVAL__::REQUIRES;
};

=head1 METHODS

=head2 new

 $self = App::Mypp->new;

This is the object constructor.

Will use L</perl5lib> to set up C<@INC>, to search for libraries in
optional directories.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    unshift @INC, @{ $self->perl5lib };

    return $self;
}

=head2 timestamp_to_changes

Inserts a timestamp in C<Changes> on the first line looking like this:

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
        $self->_log("Add timestamp '$date' to $CHANGES_FILENAME");
        return 1;
    }

    die "Unable to update $CHANGES_FILENAME with timestamp\n";
}

=head2 update_version_info

Updates version in the top module, with the latest version from C<Changes>.

=cut

sub update_version_info {
    my $self = shift;
    my $top_module = $self->top_module;
    my $version = $self->changes->{'version'};
    my $top_module_text;

    {
        open my $MODULE, '<', $top_module or die "Read '$top_module': $!\n";
        { local $/; $top_module_text = <$MODULE> };
    }

    $top_module_text =~ s/=head1 VERSION.*?\n=/=head1 VERSION\n\n$version\n\n=/s;
    $top_module_text =~ s/^((?:our)?\s*\$VERSION)\s*=.*$/$1 = eval '$version';/m;

    {
        open my $MODULE, '>', $top_module or die "Write '$top_module': $!\n";
        print $MODULE $top_module_text;
    }

    $self->_log("Update version in '$top_module' to $version");

    return 1;
}

=head2 generate_readme

Generates a C<README> file from the plain old documentation in top
module.

=cut

sub generate_readme {
    my $self = shift;
    return $self->_system(
        sprintf '%s %s > %s', 'perldoc -tT', $self->top_module, 'README'
    ) ? 0 : 1;
}

=head2 clean

Removes all files which should not be part of your repo.

=cut

sub clean {
    my $self = shift;
    my $name = $self->name;

    $self->_system('make reset');

    return 1;
}

=head2 makefile

Creates a C<Makefile.PL>, unless it already exists.

=cut

sub makefile {
    my $self = shift;
    my $name = $self->name;
    my(%requires, $repo);

    die "$MAKEFILE_FILENAME already exist\n" if(-e $MAKEFILE_FILENAME);

    open my $MAKEFILE, '>', $MAKEFILE_FILENAME or die "Write '$MAKEFILE_FILENAME': $!\n";

    printf $MAKEFILE "use inc::Module::Install;\n\n";
    printf $MAKEFILE "name q(%s);\n", $self->name;
    printf $MAKEFILE "all_from q(%s);\n", $self->top_module;

    if(%requires = $self->requires('lib')) {
        print $MAKEFILE "\n";
    }
    for my $name (sort keys %requires) {
        printf $MAKEFILE "requires q(%s) => %s;\n", $name, $requires{$name};
    }

    if(%requires = $self->requires('t')) {
        print $MAKEFILE "\n";
    }
    for my $name (sort keys %requires) {
        printf $MAKEFILE "test_requires q(%s) => %s;\n", $name, $requires{$name};
    }

    $repo = (qx/git remote show -n origin/ =~ /URL: (.*)$/m)[0] || 'git://github.com/';
    $repo =~ s#^[^:]+:#git://github.com/#;

    print $MAKEFILE "\n";
    print $MAKEFILE "bugtracker q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=$name);\n";
    print $MAKEFILE "homepage q(http://search.cpan.org/dist/$name);\n";
    print $MAKEFILE "repository q($repo);\n";
    print $MAKEFILE "\n";
    print $MAKEFILE "catalyst;\n" if($INC{'Catalyst.pm'});
    print $MAKEFILE "# install_script glob('bin/*');\n";
    print $MAKEFILE "auto_install;\n";
    print $MAKEFILE "WriteAll;\n";

    $self->_log("Created $MAKEFILE_FILENAME");

    return 1;
}

=head2 requires(lib|t)

Searches for required modules in either the C<lib/> or C<t/> directory.

=cut

sub requires {
    my $self = shift;
    my $dir = shift;
    my $prefix = $self->top_module_name;
    my %requires;

    local @INC = ('lib', grep { $_ ne 'lib' } @INC);

    finddepth({
        no_chdir => 1,
        wanted => sub {
            return if(!-f $_);
            return if(/\.swp/);
            return $self->_pm_requires($_ => \%requires) if(/\.pm$/);
            return $self->_script_requires($_ => \%requires);
        },
    }, $dir);

    for my $module (keys %requires) {
        delete $requires{$module} if($module =~ /^$prefix/);
    }

    return %requires if(wantarray);
    return \%requires;
}

sub _pm_requires {
    my $self = shift;
    my $file = shift;
    my $requires = shift;
    my $required_module = $self->_filename_to_module($file);
    my @modules;

    {
        local $SIG{'__WARN__'} = sub { print $_[0] unless($_[0] =~ /\sredefined\sat/)};
        local @INC = (sub {
            my $module = $self->_filename_to_module(pop);
            push @modules, $module if(caller(0) =~ /^$required_module/);
        }, @INC);

        eval "use $required_module (); 1" or warn $@;
        return if($@);
    }

    if(my $meta = eval "$required_module\->meta") {
        if($meta->isa('Class::MOP::Class')) {
            my $roles = $meta->can('roles') ? $meta->roles : [];
            push @modules, $meta->superclasses, map { split /\|/, $_->name } @$roles;
        }
        else {
            push @modules, map { split /\|/, $_->name } @{ $meta->get_roles };
        }
    }
    else {
        push @modules, eval "\@$required_module\::ISA";
    }

    for my $m (@modules) {
        my($module, $version) = $self->_version_from_module($m) or next;
        $requires->{$module} = $version;
    }

    return 1;
}

sub _script_requires {
    my $self = shift;
    my $file = shift;
    my $requires = shift;
    my $modules = $self->_eval_package_requires;

    open my $FH, '<', $file or die "Read $file: $!\n";

    local @$modules = ();

    while(<$FH>) {
        if(/^\s*use \s ([A-Z]\S+) ;/x) {
            eval "__EVAL__::use('$1');" or warn "$1 => $@";
        }
        elsif(/^\s*require \s ([A-Z]\S+) ;/x) {
            eval "__EVAL__::require('$1');" or warn "$1 => $@";
        }
        elsif(/^\s*use \s (base .*) ;/x) {
            eval "__EVAL__::$1;" or warn "$1 => $@";
        }
        elsif(/^\s*(extends [\(\s] .*)/x) {
            eval "__EVAL__::$1;" or warn "$1 => $@";
        }
        elsif(/^\s*(with [\(\s] .*)/x) {
            eval "__EVAL__::$1;" or warn "$1 => $@";
        }
    }

    for my $m (@$modules) {
        local $SIG{'__WARN__'} = sub { print $_[0] unless($_[0] =~ /\sredefined\sat/)};
        eval "use $m (); 1" or warn $@;
        my($module, $version) = $self->_version_from_module($m) or next;
        $requires->{$module} = $version;
    }

    return 1;
}

=head2 manifest

Creates C<MANIFEST> and C<MANIFEST.SKIP>.

=cut

sub manifest {
    my $self = shift;

    open my $SKIP, '>', 'MANIFEST.SKIP' or die "Write 'MANIFEST.SKIP': $!\n";
    print $SKIP "$_\n" for qw(
                           ^mypp.yml
                           .git
                           \.old
                           \.swp
                           ~$
                           ^blib/
                           ^Makefile$
                           ^MANIFEST.*
                       ), $self->name;

    $self->make('manifest') and die "Execute 'make manifest' failed\n";

    return 1;
}

=head2 make($what);

Creates C<Makefile.PL>, unless it already exists, then run perl on the
make script, and then execute C<make $what>.

=cut

sub make {
    my $self = shift;
    $self->makefile unless(-e $MAKEFILE_FILENAME);
    $self->_system(perl => $MAKEFILE_FILENAME) unless(-e 'Makefile');
    $self->_system(make => @_);
}

=head2 tag_and_commit

Commits with the text from C<Changes> and create a tag.

=cut

sub tag_and_commit {
    my $self = shift;
    $self->_system(git => commit => -a => -m => $self->changes->{'text'});
    $self->_system(git => tag => $self->changes->{'version'});
    return 1;
}

=head2 share_via_git

Uses git to push changes and tags to "origin". The changes are
pushed to the currently active branch.

=cut

sub share_via_git {
    my $self = shift;
    my $branch = (qx/git branch/ =~ /\* (.*)$/m)[0];

    chomp $branch;

    $self->_system(git => push => origin => $branch);
    $self->_system(git => push => '--tags' => 'origin');

    return 1;
}

=head2 share_via_extension

Uses the L</share_extension> module and upload the dist file.

=cut

sub share_via_extension {
    my $self = shift;
    my $file = $self->dist_file;
    my $share_extension = $self->share_extension;

    eval "use $share_extension; 1" or die "This feature requires $share_extension to be installed";

    # might die...
    if($share_extension eq 'CPAN::Uploader') {
        my $pause = $self->pause_info;
        $share_extension->upload_file($file, {
            user => $pause->{'user'},
            password => $pause->{'password'},
        });
    }
    else {
        $share_extension->upload_file($file, @{ $self->share_params || [] });
    }

    return 1;
}


=head2 t_pod

Create/update C<t/99-pod-coverage.t> and C<t/99-pod.t> or
C<t/00-pod-coverage.t> and C<t/00-pod.t>.

(Doesn't make any sense to wait with the pod tests to step 99)

=cut

sub t_pod {
    my $self = shift;
    my $force = shift || 0;
    my $coverage = -e 't/99-pod-coverage.t' ? 't/99-pod-coverage.t' : 't/00-pod-coverage.t';
    my $pod = -e 't/99-pod.t' ? 't/99-pod.t' : 't/00-pod.t';

    if(!-e $coverage or $force) {
        $self->_make_test($coverage, 'Test::Pod::Coverage', 'all_pod_coverage_ok({ also_private => [ qr/^[A-Z_]+$/ ] });');
    }
    if(!-e $pod or $force) {
        $self->_make_test($pod, 'Test::Pod', 'all_pod_files_ok();');
    }
}

=head2 t_load

Creates C<t/00-load.t>.

=cut

sub t_load {
    my $self = shift;
    my $force = shift || 0;
    my $load = 't/00-load.t';

    if(!-e $load or $force) {
        $self->_make_test($load, 'Test::Compile', 'all_pm_files_ok();');
    }

    return 1;
}

sub _make_test {
    my($self, $file, $module, $pod) = @_;
    my $code = "use $module;1";
    my @lib = ('lib', @{ $self->perl5lib });

    mkdir 't' unless(-d 't');
    open my $TEST, '>', $file or die "Write '$file': $!\n";
    print $TEST "use lib qw(@lib);\n";
    print $TEST "use Test::More;\n";
    print $TEST "eval '$code' or plan skip_all => '$module required';\n";
    print $TEST $pod;

    $self->_log("Created $file");
    warn "$code failed!" unless eval $code;

    return 1;
}

=head2 help

Displays L</SYNOPSIS>.

=cut

sub help {
    open my $POD, '<', __FILE__ or die "Could not open App::Mypp: $!\n";
    my $print;

    while(<$POD>) {
        if($print) {
            return 1 if(/^=\w+/);
            print;
        }
        elsif(/=head1 SYNOPSIS/) {
            $print = 1;
        }
    }

    return 2;
}

sub _system {
    shift->_log("\$ @_");
    open STDERR, '>', '/dev/null' if($SILENT);
    open STDOUT, '>', '/dev/null' if($SILENT);
    system @_;
    open STDERR, '>&', $OLDERR if($SILENT);
    open STDOUT, '>&', $OLDOUT if($SILENT);
    return $?;
}

sub _filename_to_module {
    local $_ = $_[1];
    s,\.pm,,;
    s,^/?lib/,,g;
    s,/,::,g;
    return $_;
}

sub _version_from_module {
    my $self = shift;
    my $module = shift;

    while($module) {
        if(my $version = eval "\$$module\::VERSION") {
            return($module, $version);
        }
        $module =~ s/::\w+$// or last;
    }

    return;
}

sub _log {
    return if $SILENT;
    print $_[1], "\n";
}

=head1 SEE ALSO

=over

=item * L<App::Cpanminus>

=item * L<Dist::Zilla>

=item * L<Shipit>

=item * L<http://jhthorsen.github.com/app-mypp>

=back

=head1 BUGS

Report bugs and issues at L<http://github.com/jhthorsen/app-mypp/issues>.

=head1 COPYRIGHT & LICENSE

Copyright 2007-2010 Jan Henning Thorsen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. 

=head1 AUTHOR

Jan Henning Thorsen, C<jhthorsen at cpan.org>

=cut

1;
