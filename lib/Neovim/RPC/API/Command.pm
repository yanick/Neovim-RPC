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
    handles => { 
        all_parameters => 'elements',
        num_parameters => 'count',
    },
);

has receives_channel_id => (
    is => 'ro',
);

has return_type => (
    is => 'ro',
);

sub args_to_struct {
    my( $self, @args ) = @_;


    my $is_hash = @args == 2 * $self->num_parameters;
    my %args = $is_hash ? @args : ();

    [ 
        pairmap {
            my $type = $self->api->types->{$a};
            defined $type
                ? MsgPack::Type::Ext->new( type => $type, data => $b )->data
                : $b
        }
        map { $_->[0] => $is_hash ? $args{$_->[1]} : shift @args } $self->all_parameters ]
}

sub encode {
    my $self = shift;
    my $struct = @_ == 1 ? shift : $self->to_struct(@_);

    return MsgPack::Encoder->new( struct => $struct );
}

1;

