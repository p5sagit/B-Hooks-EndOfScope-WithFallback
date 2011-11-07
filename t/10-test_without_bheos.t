use strict;
use warnings;
use Test::More;

use B::Hooks::EndOfScope::WithFallback;

plan skip_all => "Tests already executed without B::Hooks::EndOfScope"
  unless B::Hooks::EndOfScope::WithFallback::__HAS_BHEOS;

plan skip_all => "Variable::Magic still required for this test"
  unless B::Hooks::EndOfScope::WithFallback::__HAS_VM;

eval { require Devel::Hide }
  or plan skip_all => "Devel::Hide required for this test in presence of B::Hooks::EndOfScope";

use Config;
use FindBin qw($Bin);
use IPC::Open2 qw(open2);

# for the $^X-es
$ENV{PERL5LIB} = join ($Config{path_sep}, @INC);

# rerun the tests under the assumption of no bheos but a present vm

for my $fn (glob("$Bin/*.t")) {
  next if $fn =~ /test_without_/;

  local $ENV{DEVEL_HIDE_VERBOSE} = 0;
  note "retesting $fn";
  my @cmd = ( $^X, '-MDevel::Hide=B::Hooks::EndOfScope', $fn );

  # this is cheating, and may even hang here and there (testing on windows passed fine)
  # if it does - will have to fix it somehow (really *REALLY* don't want to pull
  # in IPC::Cmd just for a fucking test)
  # the alternative would be to have an ENV check in each test to force a subtest
  open2(my $out, my $in, @cmd);
  while (my $ln = <$out>) {
    print "   $ln";
  }

  wait;
  ok (! $?, "Exit $? from: @cmd");
}

done_testing;
