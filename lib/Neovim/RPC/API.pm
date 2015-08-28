package Neovim::RPC::API;

use strict;
use warnings;

use Moose::Role;

use List::AllUtils qw/ any /;

with 'MooseX::Role::Loggable';

has "rpc" => (
    isa => 'Neovim::RPC',
    is => 'ro',
    required => 1,
);

has commands => (
    traits => [ 'Array' ],
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
    handles => {
        _push_command => 'push',
        all_commands => 'elements',
    },
);

sub has_command {
    my( $self, $command ) = @_;
    return any { $_->{name} eq $command } $self->all_commands;
}

sub add_command {
    my( $self, $command ) = @_;

    my $c = Neovim::RPC::API::Command->new($command);
    $self->_push_command($c);

    $self->meta->add_method( $c->name => sub {
        shift;
        my %args = @_;

        my $struct = $c->to_struct(%args);

        my $future = $self->rpc->add_reply_callback( $struct->[1] );

        $self->log( [ "sending %s", $struct] );
        $self->rpc->socket->send($c->encode($struct));

        $future;
    })

}


1;



