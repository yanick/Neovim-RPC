package Neovim::RPC::Plugin::Echo;
# ABSTRACT: echo back message to nvim

use 5.20.0;

use strict;
use warnings;

use Neovim::RPC::Plugin;

use experimental qw/ signatures /;

subscribe echo => sub($self,$event) {
    my $message = $event->params->[0];
    $self->api->vim_command( qq{echo "$message"} );
};

1;



