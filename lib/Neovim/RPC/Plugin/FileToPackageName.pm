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

        my $y = 
        $self->api->vim_call_function( fname => 'expand', args => [ '%:p' ] )
        ->then( sub {
            $self->api->vim_set_current_line( line => 'package ' . file_to_package_name(shift) . ';' ) 
        });

        $y->on_done(sub{
            $y; # to get around the silly 'weaken' bug
            $msg->done;
        });

    });
}

1;



