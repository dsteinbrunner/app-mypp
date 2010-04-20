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

=head1 ATTRIBUTES

=head1 METHODS

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
