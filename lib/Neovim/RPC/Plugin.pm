package Neovim::RPC::Plugin;

use strict;
use warnings;

use Moose::Role;

has "rpc" => (
    is => 'ro',
    required => 1,
    handles => [ 'api', 'subscribe' ],
);


1;

