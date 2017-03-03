package Neovim::RPC::API::AutoDiscover;

use strict;
use warnings;

use Moose;
with 'Neovim::RPC::API';

use Promises qw/ deferred /;

use experimental 'postderef';

sub BUILD {
    my $self = shift;
    
    $self->add_command({ name => 'vim_get_api_info' });

    my $promise = deferred;

    $self->vim_get_api_info->done(sub {
        my( $response ) = @_;

        $self->channel_id( $response->[0] );

        my @funcs = $response->[1]{'functions'}->@*;

        for my $f ( @funcs ) {
            next if $self->has_command( $f->{name} );
            $self->log( [ "adding function %s", $f->{name} ] );
            $self->add_command( $f );
        }

        while ( my ( $type, $val ) = each $response->[1]{'types'}->%* ) {
            $self->types->{$type} = $val->{id};
        }

        $self->vim_set_var( name => 'nvimx_channel', value => $self->channel_id );

        $promise->resolve;
    } );

    $self->rpc->loop( $promise );
}

1;


