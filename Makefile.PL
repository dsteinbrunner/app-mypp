use inc::Module::Install;

name q(App-Mypp);
all_from q(lib/App/Mypp.pm);

bugtracker q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Mypp);
homepage q(http://search.cpan.org/dist/App-Mypp);
repository q(git://github.com/jhthorsen/app-mypp.git);

auto_install;
WriteAll;
