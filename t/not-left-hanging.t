use 5.20.0;

use strict;
use warnings;

use Test::More;

plan skip_all => 'no nvim listening' unless $ENV{NVIM_LISTEN_ADDRESS};

use Neovim::RPC;
use Future;

use experimental 'signatures';

my $rpc = Neovim::RPC->new( log_to_stderr => 1 );

my $end_loop = Future->new;


$rpc->api->vim_set_current_line( line => 'foo' );

$rpc->api->vim_eval( str => 'rpcrequest( nvimx_channel, "foo", "dummy" )')->on_fail( sub($resp){
    pass "the call is answered";
    is $resp->[1] => 'Vim:no subscriber', "right error message";
    $end_loop->done;
});

$rpc->loop($end_loop);






