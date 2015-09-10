package Neovim::RPC::Plugin::FileToPackageName;

use 5.20.0;

use strict;
use warnings;

use Moose;
with 'Neovim::RPC::Plugin';

sub file_to_package_name {
    shift
    =~ s#^(.*/)?lib/##r
    =~ s#^/##r
    =~ s#/#::#rg
    =~ s#\.p[ml]$##r;
}

sub BUILD {
    my $self = shift;

    $self->subscribe( 'file_to_package_name', sub {
        my $msg = shift;

        $self->api->vim_call_function( fname => 'expand', args => [ '%:p' ] )
        ->on_done( sub {
            $self->api->vim_set_current_line( line => 'package ' . file_to_package_name(shift) . ';' ) 
                ->on_done(sub{
                    $msg->response->done;
                });
        });

    });
}

1;



