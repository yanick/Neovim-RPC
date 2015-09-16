#!/usr/bin/perl 

use 5.10.0;

use strict;
use warnings;

use Neovim::RPC;

my $rpc = Neovim::RPC->new(
    log_to_stderr => 1,
);

    use Data::Printer;

$rpc->api->vim_get_buffers->on_done(sub{
        p @_;
});
$rpc->api->vim_get_current_buffer->on_done(sub{
    warn ord $_[0]->data;
});

$rpc->api->buffer_get_name( buffer => chr(2) )->on_done(sub{
    p @_;
});


$rpc->loop;


