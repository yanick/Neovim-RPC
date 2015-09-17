#!/usr/bin/perl 

use 5.10.0;

use strict;
use warnings;

use lib 't/lib';

#use Test::Neovim qw/ $rpc /;
use Test::More;

plan skip_all => 'not ready';

plan tests => 2;

my $rpc;

$rpc->api->vim_get_buffers->on_done(sub{
    ok scalar @_, "at least one buffer";
});

my $buffer_id;

my $f = $rpc->api->vim_get_current_buffer->on_done(sub{
    $buffer_id = ord $_[0]->data;
    ok $buffer_id, 'got a buffer id';
});

$rpc->loop($f);


