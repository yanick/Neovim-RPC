#!/usr/bin/perl 

use 5.10.0;

use strict;
use warnings;

my $socket = IO::Socket::INET->new('127.0.0.1:6666');

use Neovim::RPC::API::Command;
use Neovim::RPC::API;

use Neovim::RPC;

my $rpc = Neovim::RPC->new(
    port => 6666,
log_to_stderr => 1,
debug => 1,
);

$rpc->api->vim_subscribe( event => 'potato') for 1..2;

$rpc->subscribe( 'potato' => sub {
    my $event = shift;
    say $event->all_args;
});


$rpc->api->vim_set_current_line( line => "victory!" )
    ->on_done( sub {
        $rpc->api->print_commands;
        my( $response ) = @_;
        $rpc->api->vim_set_current_line( line => 'even better!' );
    });


$rpc->loop;
