package Neovim::RPC::Plugin::LoadPlugin;

use 5.20.0;

use strict;
use warnings;

use Neovim::RPC::Plugin;

use Try::Tiny;

use experimental 'signatures';

use Promises qw/ deferred collect /;

sub BUILD ($self,@) {
    $self->api->ready->then(sub{
        $self->api->nvim_get_var('nvimx_plugins')->then(sub{
            $self->_load_plugin($_) for keys %{ $_[0] };
        });
    });
}

subscribe load_plugin => rpcrequest sub($self,$event) {
    collect(
        map { $self->_load_plugin($_) } $event->all_params
    )->catch(sub{ warn shift });
};

subscribe plugins_loaded => sub($self,$event) {
    my $plugins = join "\n", 
       keys %{ $self->rpc->plugins };

    $self->rpc->api->vim_command( qq{echo "plugins:\n$plugins"} );
    $self->rpc->api->vim_command( qq{echo "plugins:\n} . $INC{'Neovim/RPC/Plugin/FlipOperator.pm'} );
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
