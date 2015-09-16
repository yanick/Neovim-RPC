package Neovim::RPC::API::Command;

use strict;
use warnings;

use Moose;
use MsgPack::Encoder;
use MsgPack::Type::Ext;

use List::Util qw/ pairmap /;

use experimental 'postderef';

has api => (
    is => 'ro',
);

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

sub args_to_struct {
    my( $self, %args ) = @_;

    [ 
        pairmap {
            my $type = $self->api->types->{$a};
            defined $type
                ? MsgPack::Type::Ext->new( type => $type, data => $b )
                : $b
        }
        map { $_->[0] => $args{$_->[1]} } $self->parameters->@* ]
}

sub encode {
    my $self = shift;
    my $struct = @_ == 1 ? shift : $self->to_struct(@_);

    return MsgPack::Encoder->new( struct => $struct );
}

1;

