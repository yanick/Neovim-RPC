#!/usr/bin/env perl 

package Neovim::RPC::App;

use 5.10.0;

use strict;
use warnings;

use MooseX::App::Simple;

use Getopt::Long;
use Neovim::RPC;

option std => (
    is => 'ro',
    documentation => 'use stdin/stdout',
    isa => 'Bool',
);

option include => (
    cmd_aliases => [ 'I' ],
    is => 'ro',
    documentation => 'custom library path',
    trigger => sub {
        push @INC, split ',', $_[1];
    },
);

parameter io => (
    documentation => 'socket/address to use, defaults to NVIM_LISTEN_ADDRESS',
    is => 'ro',
    lazy => 1,
    default => sub { 
        return [*STDIN, *STDOUT] if $_[0]->std;

        $ENV{NVIM_LISTEN_ADDRESS}
            or die "io not provided and NVIM_LISTEN_ADDRESS not set\n"
    },
);

has rpc => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $rpc = Neovim::RPC->new(
            io            => $_[0]->io,
            log_to_stdout => 1,
        );

        $rpc->load_plugin( 'LoadPlugin' );

        return $rpc;
    },
);


sub run {
    my $self = shift;

    warn @ARGV;

    warn "here";
    
    $self->rpc->loop;
}

1;

Neovim::RPC::App->new_with_options->run;
