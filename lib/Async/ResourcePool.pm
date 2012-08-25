package Async::ResourcePool;

=head1 NAME

Async::ResourcePool - Resource pooling for asynchronous programs.

=head1 DESCRIPTION

This module implements the simple functionality of creating a source pool for
event-based/asynchronous programs.  It provides consumers with the ability to
have some code execute whenever a resource happens to be ready.  Further, it
allows resources to be categorized (by label) and limited as such.

=cut

use strict;
use warnings FATAL => "all";

=head1 CONSTRUCTOR

=over 4

=item new [ ATTRIBUTES ]

=cut

sub new {
    my ($class, %params) = @_;

    my $self = bless {
        %params,

        _resources  => {},
        _allocated  => 0,
        _wait_queue => [],
        _available  => [],
    }, $class;

    return $self;
}

=back

=cut

=head1 ATTRIBUTES

=over 4

=item factory -> CodeRef(POOL, CodeRef(RESOURCE, MESSAGE))

The factory for generating the resource.  The factory is a subroutine reference
which accepts an instance of this object and a callback as a reference.  The
callback, to be invoked when the resource has been allocated.

If no resource could be allocated due to error, then undef should be supplied
with the second argument being a string describing the failure.

=cut

sub factory {
    my ($self, $value) = @_;

    if (@_ == 2) {
        $self->{factory} = $value;
    }

    $self->{factory};
}

=item limit -> Int

The number of resources to create per label.

Optional.

=cut

sub limit {
    my ($self, $value) = @_;

    if (@_ == 2) {
        $self->{limit} = $value;
    }

    $self->{limit};
}

=head1 METHODS

=over 4

=item lease RESOURCE_NAME, CALLBACK

=cut

sub has_waiters {
    return scalar @{ shift->{_wait_queue} };
}

sub has_available {
    return scalar @{ shift->{_available} };
}

sub _track_resource {
    my ($self, $resource) = @_;

    $self->{_resources}->{$resource} = $resource;
}

sub _prevent_halt {
    my ($self) = @_;

    if ($self->has_waiters) {
        $self->lease(shift $self->{_wait_queue});
    }
}

sub lease {
    my ($self, $callback) = @_;

    if ($self->has_available) {
        my $resource = pop $self->{_available};

        $callback->($resource);
    }
    else {
        my $allocated = $self->{_allocated};

        unless ($allocated == $self->limit) {
            $self->{_allocated}++;

            $self->factory->(
                $self,
                sub {
                    my ($resource, $message) = @_;

                    if (defined $resource) {
                        $self->_track_resource($resource);

                        warn "$resource: tracking";
                    }
                    else {
                        # Decrement the semaphore so that we don't
                        # degrade the pool on an error state.
                        $self->{_allocated}--;

                        # Prevent halting by reentering the allocation
                        # routine if we have waiters, since we just
                        # lost a resource from the semaphore.
                        $self->_prevent_halt;
                    }

                    $callback->($resource, $message);
                }
            );
        }
        else {
            push $self->{_wait_queue}, $callback;
        }
    }
}

sub release {
    my ($self, $resource) = @_;

    warn "$self: waiting";

    if ($self->has_waiters) {
        my $callback = shift $self->{_wait_queue};

        $callback->($resource);
    }
}

sub invalidate {
    my ($self, $resource) = @_;

    if (delete $self->{_resources}->{$resource}) {
        $self->_prevent_halt;
    }
}

return __PACKAGE__;
