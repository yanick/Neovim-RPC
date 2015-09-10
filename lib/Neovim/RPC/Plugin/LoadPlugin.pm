package Neovim::RPC::Plugin::LoadPlugin;

use 5.20.0;

use strict;
use warnings;

use Moose;
with 'Neovim::RPC::Plugin';

use Try::Tiny;

use experimental 'signatures';

sub BUILD($self,@) {

    $self->subscribe('load_plugin',sub ($msg) { 
        # TODO also deal with it as a request?
        my $plugin = $msg->args->[0];
        try {
            $self->rpc->load_plugin( $plugin );           
        }
        catch {
            $self->api->vim_report_error( str => "failed to load $plugin" );
        }
    });
}


1;


