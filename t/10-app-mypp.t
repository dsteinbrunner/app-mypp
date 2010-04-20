use strict;
use warnings;
use lib q(lib);
use Test::More;
use App::Mypp;

plan tests =>
      1 # various
    + 8 # attributes
    + 4 # methods
;

init();
my $app;

eval {
    $app = App::Mypp->new;
    ok($app, 'App::Mypp instace constructed');
} or BAIL_OUT 'Cannot construct object';

eval { # attributes
    is(ref $app->config, 'HASH', 'attr config is a hash ref');
    is($app->config->{'just_to_make_test_work'}, 42, 'attr config is read');
    is($app->name, 'App-Mypp', 'attr name = App-Mypp');
    is($app->top_module, 'lib/App/Mypp.pm', 'attr top_module = lib/App/Mypp.pm');
    is($app->top_module_name, 'App::Mypp', 'attr top_module_name = App::Mypp');
    is(ref $app->changes, 'HASH', 'attr changes is a hash ref');
    like($app->changes->{'text'}, qr{^0\.01.*Init repo}s, 'changes->text is set');
    is($app->changes->{'version'}, '0.01', 'changes->version is set');
} or BAIL_OUT "something bad happened: $@";

eval { # methods
    ok($app->timestamp_to_changes, 'timestamp_to_changes() succeeded');
    ok($app->update_version_info, 'update_version_info() succeeded');
    ok($app->generate_readme, 'generate_readme() succeeded');

    TODO: {
        todo_skip 'will this disrupt test? possible race condition', 1;
        ok($app->clean, 'clean() succeeded');
    };

    1;
} or BAIL_OUT "something bad happened: $@";

#==============================================================================
sub init {
    $App::Mypp::SILENT = 1;
    $App::Mypp::CHANGES_FILENAME = 't/Changes.test';

    open my $CHANGES, '>', $App::Mypp::CHANGES_FILENAME or BAIL_OUT 'cannot write to t/Changes.test';

    print $CHANGES <<'CHANGES';
Revision history for App-Mypp

0.01
 * Init repo

CHANGES
}

END {
    unlink $App::Mypp::CHANGES_FILENAME or diag "could not unlink t/Changes.test";
}
