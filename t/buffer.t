#!/usr/bin/perl 

use 5.10.0;

use strict;
use warnings;

use lib 't/lib';

use Test::Neovim qw/ $rpc /;
use Test::More;

plan tests => 2;

$rpc->api->export_dsl(1);

vim_get_buffers()->on_done(sub{
    ok scalar @_, "at least one buffer";
});

my $buffer_id;

vim_get_current_buffer()->on_done(sub{
    $buffer_id = ord $_[0]->data;
    ok $buffer_id, 'got a buffer id';
});

