package Coro::Generator;

=head1 NAME

Coro::Generator - Create generators using Coro

=head1 SYNOPSIS

  use strict;
  use Coro::Generator;

  my $even = generator {
    my $x = 0;
    while(1) {
      $x++; $x++;
      yield $x;
    }
  };

  # This will print even numbers from 2..20
  for my $i (1..10) {
    print $even->() . "\n";
  }

=head1 DESCRIPTION

In the words of wikipedia, generators look like functions but act like
iterators.

=head1 WHY USE THIS?

My own use of this is for a technique called 'Inversion of Control'. The idea
is to let one piece of the program think it's in control even though it isn't.
Though it is true that this sort of psychological warfare with the beliefs of
your code can be mind-bending, if you go with the flow (HAHAHA) it can often
make for much more readable code. Google up the 'actor model' or something like
that if you want some further thoughts on that.

So, for the sake of illustration, let's rename C<yeild> to C<gimme_more_input>
in this example:

  use Coro::Generator qw( generator gimme_more_input );

  my $processor = generator {
    my $i = 0;
    while(1) {
      my $input = gimme_more_input($i);
      $i += $input;
    }
  };

  sub count_jump {
    my $current_count = shift;
    print "Count: $current_count\n";
    print "Add to that: ";
    my $add = <>;
    chomp $add;
    return $add;
  }

  my $count = $processor->();
  while(1) {
    my $addsome = count_jump($count);
    $count = $processor->( $addsome );
  }

... note that the generator thinks that it is the thing looking and getting
input, when in fact it is the main while loop that is actually looping and
getting input. Noodle that a bit.

=head1 EXPORTS

The C<generator> and C<yeild> functions are exported by default. They can be
imported as a different name by passing the names in as arguments to the C<use>
statement, e.g.

  use Coro::Generator; # import 'generator' and 'yield'
  use Coro::Generator qw( generator yield ); # ditto
  use Coro::Generator qw( fiber yield ); # import it as fiber

Calling C<yield> outside (the execution of) a generator will likely do horrible
things. So... don't do that.

=cut

use strict;
use Coro;
our $VERSION = '0.3.0';

our @yieldstack;
our $retval;
our @params;

=head1 SUBROUTINES

=head2 C<< $g = generator { ... }; >>

This creates a generator, and assigns it to $g. It is kinda like a subref:

  $f = sub { ... }

except it needs a 'C<;>' at the end. This generator can be invoked just like a
subref, but it has added ability to remember it's full state between
invocations -- including not only lexical variables but also where it was in
its computation (control flow state). So if you have:

  $count = generator {
    my $i;
    while(1) {
      yield $i++
    }
  };

You get a generator named $count. You can call it over and over again, just
like a normal subref, but each time you call it you'll get one bigger number
than the time before.

=cut

sub generator (&) {
  my $code = shift;
  my $prev = new Coro::State;
  my $coro = Coro::State->new(sub {
    yield();
    $code->(@params) while 1;
  });
  push @yieldstack, [$coro, $prev];
  $prev->transfer($coro);
  return sub {
    @params = @_;
    push @yieldstack, [$coro, $prev];
    $prev->transfer($coro);
    return $retval;
  };
}

=head2 C<< @new_params = yield( $return_value ); >>

When you are ready to return an intermediate result from within your generator,
use C<yeild>. I read it as "I am YIELDING my current result". It's kinda like
return... but it isn't the end of your subroutine.

When someone invokes your generator again they can pass in some more
parameters, just like when they called it the first time. Whatever they pass in
is returned by your yield call.

=cut

sub yield {
  $retval = shift;
  my ($coro, $prev) = @{pop @yieldstack};
  $coro->transfer($prev);
  return wantarray ? @params : $params[0];
}

sub import {
  my $class = shift;
  my $generator_name = shift || 'generator';
  my $yield_name = shift || 'yield';
  my $caller = caller();

  no strict 'refs';
  *{"$caller\::$generator_name"} = \&generator;
  *{"$caller\::$yield_name"} = \&yield;
}

=head1 SEE ALSO

L<Coro>

=head1 AUTHOR

Brock Wilcox, E<lt>awwaiid@thelackthereof.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Brock Wilcox

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself, either Perl version 5.12.1 or, at your option,
any later version of Perl 5 you may have available.

=cut

1;

