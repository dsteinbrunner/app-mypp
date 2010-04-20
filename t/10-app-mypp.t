use strict;
use warnings;
use lib q(lib);
use Test::More;
use App::Mypp;

plan tests => 1 + 5;

my $app = App::Mypp->new;

ok($app, 'App::Mypp instace constructed') or BAIL_OUT 'Cannot construct object';

{ # attributes
    is(ref $app->config, 'HASH', 'attr config is a hash ref');
    is($app->config->{'just_to_make_test_work'}, 42, 'attr config is read');
    is($app->name, 'App-Mypp', 'attr name = App-Mypp');
    is($app->top_module, 'lib/App/Mypp.pm', 'attr top_module = lib/App/Mypp.pm');
    is($app->top_module_name, 'App::Mypp', 'attr top_module_name = App::Mypp');
}
