use strict;
use warnings;
use Test::More;

use B::Hooks::EndOfScope::WithFallback;

plan skip_all => 'Skipping fallback test in XS mode'
  if B::Hooks::EndOfScope::WithFallback::__HAS_VM;

pass ('Expecting a regular exit, no segfaults');

# because of the immediate _exit() we need to output the
# plan-end ourselves
print "1..1\n";

# tweak the exit code
$ENV{B_HOOKS_EOS_PP_ON_DIE_EXITCODE} = 0;

# move STDERR to STDOUT to not flood the diag with crap
*STDERR = *STDOUT;

eval q[
    sub foo {
        BEGIN {
            on_scope_end { die 'bar' };
        }
    }
];

