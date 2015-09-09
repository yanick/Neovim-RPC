package Neovim::RPC::API::AutoDiscover;

use strict;
use warnings;

use Moose;
with 'Neovim::RPC::API';

use experimental 'postderef';

sub BUILD {
    my $self = shift;
    
    $self->add_command({ name => 'vim_get_api_info' });

    my $done;

    $self->vim_get_api_info->on_done(sub {
        my( $response ) = @_;

        $self->channel_id( $response->[0] );

        my @funcs = $response->[1]{'functions'}->@*;

        for my $f ( @funcs ) {
            next if $self->has_command( $f->{name} );
            $self->log( [ "adding function %s", $f->{name} ] );
            $self->add_command( $f );
        }

        $done = 1;
    } );

    $self->rpc->loop( until => sub { $done } );
}

1;


