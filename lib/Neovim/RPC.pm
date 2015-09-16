package Neovim::RPC;
# ABSTRACT: RPC client for Neovim

use strict;
use warnings;

use Moose;
use IO::Socket::INET;
use MsgPack::RPC;
use Neovim::RPC::API::AutoDiscover;
use MsgPack::Decoder;
use Future;
use Class::Load qw/ load_class /;

use experimental 'signatures';

extends 'MsgPack::RPC';

has '+io' => (
    builder => '_build_io'
);

sub _build_io {
    my $self = shift;

    my $io =$ENV{NVIM_LISTEN_ADDRESS} || do {
        open my $in,  '<', '-';
        open my $out, '>', '-';
        [ $in, $out ];
    };

    $self->_set_io_accessors($io);
    $io;
}

has "api" => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        Neovim::RPC::API::AutoDiscover->new( rpc => $self, logger => $self->logger );      
    },
);

before subscribe => sub($self,$event,@){
    $self->api->vim_subscribe( event => $event );
};

0 and around emit_request => sub {
    my( $orig, $self, @args ) = @_;
    my $event = $orig->($self,@args);
    $event->response->fail("no subscriber") unless $event->response->is_ready;
    $event;
};

has plugins => (
    traits => [ 'Array' ],
    isa => 'ArrayRef',
    default => sub { [] },
    handles => {
        _push_plugin => 'push',
    },
);

# TODO make that a coerced type
sub load_plugin ( $self, $plugin ) { 
    my $class = 'Neovim::RPC::Plugin::' . $plugin;
    $self->_push_plugin(
        load_class($class)->new( rpc => $self )
    );
}

1;
