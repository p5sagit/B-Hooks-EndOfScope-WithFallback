use strict;
use warnings;
use Test::More;

use B::Hooks::EndOfScope::WithFallback;

plan skip_all => 'Skiping XS test in fallback mode'
  unless B::Hooks::EndOfScope::WithFallback::__HAS_VM;

eval q[
    sub foo {
        BEGIN {
            on_scope_end { die 'bar' };
        }
    }
];

like($@, qr/^bar/);

pass('no segfault');

done_testing;
