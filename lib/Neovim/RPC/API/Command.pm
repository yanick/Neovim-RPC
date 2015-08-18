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
    isa => 'ArrayRef',
    is => 'ro',
    default => sub { [] },
);

has receives_channel_id => (
    is => 'ro',
);

has return_type => (
    is => 'ro',
);

sub encode {
    my( $self, %args ) = @_;

    my $struct = [ 0, $args{_id} || ++$Neovim::RPC::API::ID, $self->name, [ 
            map { $args{$_->[1] } } $self->parameters->@*
    ] ];

    return Neovim::RPC::MessagePack::Encoder->new( struct => $struct );
}

1;

