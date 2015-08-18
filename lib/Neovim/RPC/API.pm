package Neovim::RPC::API;

use strict;
use warnings;

use Moose;

has commands => (
    traits => [ 'Array' ],
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
    handles => {
        _push_command => 'push',
    },
);

sub add_command {
    my( $self, $command ) = @_;

    my $c = Neovim::RPC::API::Command->new($command);
    $self->_push_command($c);

    $self->meta->add_method( $c->name => sub {
        shift;
        $c->encode(@_);
    })

}

1;



