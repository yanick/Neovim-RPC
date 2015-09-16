package Neovim::RPC::API;

use 5.10.0;

use strict;
use warnings;

use Moose::Role;

use Neovim::RPC::API::Command;

use List::AllUtils qw/ any /;

with 'MooseX::Role::Loggable';

has "rpc" => (
    isa => 'Neovim::RPC',
    is => 'ro',
    required => 1,
);

has channel_id => (
    is => 'rw',
    isa => 'Int',
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

has types => (
    is => 'ro',
    default => sub{ {} },
);

sub print_commands {
    my( $self ) = @_;

    for my $c ( sort { $a->name cmp $b->name } $self->all_commands ) {
        say $c->name, ' ( ', join( ', ', map { join ' ', @$_ } $c->all_parameters ) , ' ) -> ',
            $c->return_type; 
    }

}

sub has_command {
    my( $self, $command ) = @_;
    return any { $_->{name} eq $command } $self->all_commands;
}

sub add_command {
    my( $self, $command ) = @_;

    $command->{api} = $self;

    my $c = Neovim::RPC::API::Command->new($command);
    $self->_push_command($c);

    $self->meta->add_method( $c->name => sub {
        shift;
        my %args = @_;

        my $struct = $c->args_to_struct(%args);

        $self->rpc->request( $c->name => $struct);
    })

}


1;



