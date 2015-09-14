#!/usr/bin/perl 

use 5.10.0;

use strict;
use warnings;

use Neovim::RPC;

my $rpc = Neovim::RPC->new(
    log_to_stderr => 1,
    #debug => 1,
);

$rpc->api->buffer_get_name( buffer => 0)->on_done(sub{
    use Data::Printer;
    p @_;
});


$rpc->loop;


