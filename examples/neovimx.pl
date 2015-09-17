#!/usr/bin/env perl 

use strict;
use warnings;

use lib '/home/yanick/work/neovim/lib';
use lib '/home/yanick/work/MessagePack/lib';

use  Neovim::RPC;

my $rpc = Neovim::RPC->new;

$rpc->load_plugin('LoadPlugin');

$rpc->loop;

