use inc::Module::Install;

name q(Some-Project);
all_from q(lib/Some/Project.pm);

requires q(Math::BigInt) => 1.89;
requires q(Moose) => 1.07;
requires q(Moose::Object) => 1.07;

test_requires q(Test::More) => 0.94;

bugtracker q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=Some-Project);
homepage q(http://search.cpan.org/dist/Some-Project);
repository q(git://github.com//home/repositories/app-mypp.git);

# install_script glob('bin/*');
auto_install;
WriteAll;
