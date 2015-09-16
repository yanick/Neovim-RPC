use 5.20.0;

use strict;
use warnings;

use Test::More;

use Neovim::RPC;
use Future;

use experimental 'signatures';

plan skip_all => 'no nvim listening' unless $ENV{NVIM_LISTEN_ADDRESS};

plan tests => 2;

my $rpc = Neovim::RPC->new;

ok $rpc->api->channel_id, "we have a channel id";

my $end_loop = Future->new;

$rpc->api->vim_get_var( name => 'nvimx_channel' )->on_done( sub($resp){
    is $resp => $rpc->api->channel_id, 'available nvim-side too';
    $end_loop->done;
});

$rpc->loop($end_loop);






