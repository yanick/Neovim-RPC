package Neovim::RPC::Plugin::LoadPlugin;

use 5.20.0;

use strict;
use warnings;

use Neovim::RPC::Plugin;

use Try::Tiny;

use experimental 'signatures';

use Promises qw/ deferred collect /;

subscribe load_plugin => sub($self,$event) {
    collect(
        map { $self->_load_plugin($_) } $event->all_args
    );
};

subscribe plugins_loaded => sub($self,$event) {
    my $plugins = join "\n", 
       keys %{ $self->rpc->plugins };

    $self->rpc->api->vim_command( qq{echo "plugins:\n $plugins"} );
};

sub _load_plugin( $self, $plugin ) {
    my $promise = deferred;
    $promise->resolve;

    $promise
        ->then(sub{ $self->rpc->load_plugin($plugin) })
        ->catch(sub{
            $self->api->vim_report_error( str => 
                "failed to load NeovimX plugin '$plugin': @_" 
            );
        });
}

1;
