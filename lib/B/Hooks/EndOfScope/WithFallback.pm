package B::Hooks::EndOfScope::WithFallback;

use strict;
use warnings;

our $VERSION = '0.01';

# note - the tie() fallback will probably work on 5.6 as well,
# if you need to go that low - patches passing tests will be accepted
use 5.008001;

my ($v_m_req, $bheos_ver);
BEGIN{
  # Adjust the Makefile.PL if changing this minimum version
  $v_m_req = '0.34';

  # FIXME - remove if merged with B::H::EOS
  $bheos_ver = '0.09';
}

BEGIN {
  *__HAS_VM = eval {
    require Variable::Magic;
    Variable::Magic->VERSION($v_m_req);
  } ? sub () { 1 } : sub () { 0 };
}

# FIXME - remove if merged with B::H::EOS
BEGIN {
  *__HAS_BHEOS = __HAS_VM && eval {
    require B::Hooks::EndOfScope;
    B::Hooks::EndOfScope->VERSION ($bheos_ver) 
  } ? sub () { 1 } : sub () { 0 };
}

use Sub::Exporter -setup => {
  exports => ['on_scope_end'],
  groups  => { default => ['on_scope_end'] },
};

=head1 NAME

B::Hooks::EndOfScope::WithFallback - B::Hooks::EndOfScope without an XS dependency

=head1 SYNOPSIS

  on_scope_end { ... };

=head1 DESCRIPTION

Just like its twin L<B::Hooks::EndOfScope> this module allows you to execute
code when perl finished compiling the surrounding scope. The only difference
is that this module will function even without the presence of the XS
dependency L<Variable::Magic>. The behavior and API is identical to that of
L<B::Hooks::EndOfScope> with the exception of one caveat as listed below.

=head1 WHY ANOTHER MODULE

While the design of the non-XS implementation is sound and passes every test
of the original L<B::Hooks::EndOfScope> distribution, the authors of
L<B::Hooks::EndOfScope> are currently not interested in integrating it into
their distribution on philosophical grounds.

=head1 CAVEATS

Handling exceptions in scope-end callbacks is tricky business. While
L<Variable::Magic> has access to some very dark sorcery to make it possible to
throw an exception from within a callback, the pure-perl impleentation does
not have access to these hacks. Therefore, what would have been a compile-time
exception is instead emulated with output on C<STDERR> and an immediate exit
via L<POSIX/_exit>. This can potentially have an impact on your code, since
no C<END> blocks, nor C<DESTROY> callbacks will execute.

=head1 FUNCTIONS

=head2 on_scope_end

    on_scope_end { ... };

    on_scope_end $code;

Registers C<$code> to be executed after the surrounding scope has been
compiled.

This is exported by default. See L<Sub::Exporter> on how to customize it.

=cut

# FIXME - remove if merged with B::H::EOS
# already loaded - might as well
if (__HAS_BHEOS) {
  *on_scope_end = \&B::Hooks::EndOfScope::on_scope_end;
}

# we have V::M - just replicate everything here, do not
# even try to load B::H::EOS (may or may not be installed)
# the amount of code is minimal anyway, and we save on
# the syscalls to find/load B/H/EOS.pm
elsif (__HAS_VM) {

  my $wiz = Variable::Magic::wizard (
    data => sub { [$_[1]] },
    free => sub { $_->() for @{ $_[1] }; () }
  );

  # str-eval so it is subnamed correctly
  eval <<'EOS' or die $@;

  sub on_scope_end (&) {
    my $cb = shift;

    $^H |= 0x020000;

    if (my $stack = Variable::Magic::getdata %^H, $wiz) {
      push @{ $stack }, $cb;
    }
    else {
      Variable::Magic::cast %^H, $wiz, $cb;
    }
  }

  1;  # for the above `or die()`

EOS
}
else {
  # str eval for the above reason and so we do not burn cycles defining
  # packages we will not use
  eval <<'EOS' or die $@;

  require Tie::Hash;

  {
    package B::Hooks::EndOfScope::WithFallback::_TieHintHash;

    use warnings;
    use strict;

    our @ISA = 'Tie::ExtraHash';
  }

  # Instead of relying on specific destruction order like the V::M
  # implementation does, use an explicit array with its own destructor
  # ordering. This is a potential FIXME for the V::M-using code (it may
  # very well start unwinding the *other* way), but leaving it as-is
  # for now to match what B::H::EOS does.
  {
    package B::Hooks::EndOfScope::WithFallback::_ScopeGuardArray;

    use warnings;
    use strict;

    sub new { bless [], ref $_[0] || $_[0] }

    sub DESTROY {
      local $@ = '';
      # keep unwinding the stack until something decides to throw
      while (@{$_[0]} and $@ eq '') {
        eval { $_[0]->[0]{code}->(); shift @{$_[0]} };
      }

      if ( (my $err = $@) ne '') {
        # argh argh argh - why did you have to throw in a scope-end?!
        # we can not properly throw during a  BEGIN from within pure-perl
        # (V::M does some very weird XS magic to be able to). However - we
        # are still compiling - so we can very well just exit() with a long
        # explanation. Exitting with a normal exit() however won't work, as
        # it causes perl to segfault (even 5.14), so doing the POSIX thing
        # instead
        my $exit_code = $ENV{B_HOOKS_EOS_PP_ON_DIE_EXITCODE};
        $exit_code = 1 if (! defined $exit_code or ! length $exit_code);

        print STDERR <<EOE; require POSIX; POSIX::_exit($exit_code);

========================================================================
               !!!   F A T A L   E R R O R   !!!

             Exception thrown by scope-end callback
========================================================================

B::Hooks::EndOfScope::WithFallback is currently operating in pure-perl
fallback mode, because your system is lacking the necessary dependency
Variable::Magic $v_m_req
In this mode B::Hooks::EndOfScope::WithFallback is unable to accomodate
callbacks throwing exception, due to the design of perl itself. Your
entire application will terminate immediately using POSIX::_exit (this
means nothing else beyond this point will execute, including any END
blocks you may have defined. The callback originally defined around
$_[0]->[0]{caller} terminated with the following error:

$err
EOE
      }
    }
  }

  sub on_scope_end (&) {
    $^H |= 0x020000;

    my $stack;
    if(my $t = tied( %^H ) ) {
      if ( (my $c = ref $t) ne 'B::Hooks::EndOfScope::WithFallback::_TieHintHash') {
        die <<EOE;

========================================================================
               !!!   F A T A L   E R R O R   !!!

                 foreign tie() of %^H detected
========================================================================

B::Hooks::EndOfScope::WithFallback is currently operating in pure-perl
fallback mode, because your system is lacking the necessary dependency
Variable::Magic $v_m_req
In this mode B::Hooks::EndOfScope::WithFallback expects to be able to tie()
the hinthash %^H, however it is apparently already tied by means unknown to
the tie-class $c

Since this is a no-win situation execution will abort here and now. Please
try to find out which other module is relying on hinthash tie() ability,
and file a bug for both the perpetrator and B::Hooks::EndOfScope::WithFallback
so that the authors can figure out an acceptable way of moving forward.

EOE
      }
      $stack = $t->[1];
    }
    else {
      tie(
        %^H,
        'B::Hooks::EndOfScope::WithFallback::_TieHintHash',
        ($stack = B::Hooks::EndOfScope::WithFallback::_ScopeGuardArray->new),
      );
    }

    my ($f, @callsite);
    do { @callsite = caller(++$f) }
      while (@callsite and $callsite[1] =~ /\(eval.+\)/);

    push @$stack, {
      code => shift(),
      caller => sprintf '%s line %s', @callsite[1,2]
    };
  }

  1;  # for the above `or die()`

EOS
}

=head1 SEE ALSO

L<B::Hooks::EndOfScope>

=head1 AUTHOR

ribasushi: Peter Rabbitson <ribasushi@cpan.org>

=head1 CONTRIBUTORS

None as of yet

=head1 COPYRIGHT

Copyright (c) 2011 the B::Hooks::EndOfScope::WithFalback L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut

1;
