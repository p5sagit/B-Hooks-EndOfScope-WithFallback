use warnings;
use strict;

# note - the tie() fallback will probably work on 5.6 as well,
# if you need to go that low - patches passing tests will be accepted
use 5.008001;

use inc::Module::Install '1.01';

my $use_pp = $ENV{B_HOOKS_EOS_USE_PP} || ! can_cc();

test_requires 'Test::More'      => '0.88';  # done testing
test_requires 'Test::Exception' => '0.31';  # non-segfaulting caller()

test_requires 'Devel::Hide'     => '0' if is_smoker();

# Adjust lib/B/Hooks/EndOfScope/WithFallback.pm if bumping this dep
requires 'Variable::Magic' => '0.34' unless $use_pp;

all_from 'lib/B/Hooks/EndOfScope/WithFallback.pm';

homepage 'http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=p5sagit/B-Hooks-EndOfScope-WithFallback.git';
resources 'IRC'         => 'irc://irc.perl.org/#pp';
resources 'license'     => 'http://dev.perl.org/licenses/';
resources 'repository'  => 'git://git.shadowcat.co.uk/p5sagit/B-Hooks-EndOfScope-WithFallback.git';
resources 'bugtracker'  => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=B-Hooks-EndOfScope-WithFallback';

auto_install();

WriteAll;

sub is_smoker {
  return ( $ENV{AUTOMATED_TESTING} && ! $ENV{PERL5_CPANM_IS_RUNNING} && ! $ENV{RELEASE_TESTING} )
}
