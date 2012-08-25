#!/usr/bin/env perl

use strict;
use warnings FATAL => "all";
use Test::More;
use Async::ResourcePool;

=head1 TESTS

=over 4

=item 

=cut

use_ok("Async::ResourcePool", "Able to include module");

package Resource {
    our $instances = 0;
    use Test::More;

    sub new {
        my ($class, %args) = @_;

        $instances++;

        return bless { %args }, $class;
    }

    sub release {
        my ($self) = @_;

        $self->{pool}->release($self);
    }

    sub close {
        my ($self) = @_;

        $instances--;

        $self->{pool}->invalidate($self);
    }
}

our @queue;

sub postpone (&) {
    splice @queue, rand(@queue / 2), 0, shift;
}

sub run () {
    while (@queue) {
        (shift @queue)->();
    }
}

subtest "Simple Resource Management" => sub {
    plan tests => 53;

    my $pool;

    unless (defined $pool) {
        $pool = Async::ResourcePool->new(
            limit   => 4,
            factory => sub {
                my ($pool, $available) = @_;

                if (rand > 0.10) {
                    my $resource = Resource->new(pool => $pool);

                    $available->($resource);
                }
                else {
                    $available->(undef, "Crap we broke");
                }
            }
        );
    }

    # Then this is in place of ->run_when_ready...
    $pool->lease(sub {
            my ($resource, $message) = @_;

            if (defined $resource) {
                ok $Resource::instances <= 4,
                "Allocated, no more than 4 allocated instances";

                # Do this later...
                postpone {
                    if (rand >= 0.2) {
                        $resource->release;
                    }
                    else {
                        $resource->close;
                    }
                }
            }
            else {
                ok defined $message, "The error passing is working";
            }
        })
    for 1 .. 50;

    run;

    ok $pool->has_available, "Probabalistically some should be available";
    ok !$pool->has_waiters, "Expected no waiters to remain";
    ok $pool->size <= $pool->limit, "The size may not exceed the limit";
};

done_testing;
