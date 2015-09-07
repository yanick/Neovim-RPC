package Neovim::RPC::API::Command;

use strict;
use warnings;

use Moose;
use Neovim::RPC::MessagePack::Encoder;

use experimental 'postderef';

has deferred => (
    is => 'ro',
    default => 1,
);

has name => (
    is => 'ro',
    required => 1,
);

has parameters => (
    traits => [ 'Array' ],
    isa => 'ArrayRef',
    is => 'ro',
    default => sub { [] },
    handles => { all_parameters => 'elements' },
);

has receives_channel_id => (
    is => 'ro',
);

has return_type => (
    is => 'ro',
);

sub to_struct {
    my( $self, %args ) = @_;

    [ 0, $args{_id} || ++$Neovim::RPC::API::ID, $self->name, [ 
            map { $args{$_->[1] } } $self->parameters->@*
    ] ];

}

sub encode {
    my $self = shift;
    my $struct = @_ == 1 ? shift : $self->to_struct(@_);

    return Neovim::RPC::MessagePack::Encoder->new( struct => $struct );
}

1;

