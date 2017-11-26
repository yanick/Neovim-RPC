package Neovim::RPC;
# ABSTRACT: RPC client for Neovim

use strict;
use warnings;

use Moose;
use IO::Socket::INET;
use MsgPack::RPC;
use Neovim::RPC::API::AutoDiscover;
use MsgPack::Decoder;
use Class::Load qw/ load_class /;

use experimental 'signatures';

extends 'MsgPack::RPC';

has '+io' => (
    builder => '_build_io'
);

sub _build_io {
    my $self = shift;

    my $io =$ENV{NVIM_LISTEN_ADDRESS} || do {
        open my $in,  '<', '-';
        open my $out, '>', '-';
        [ $in, $out ];
    };
    $self->_set_io_accessors($self->io);
    $io;
}

# sub BUILD { my $self = shift; $self->_set_io_accessors($self->io) if $self->io }

sub BUILD {
    my $self = shift;
    $self->api->ready->done(sub {
        $self->subscribe( 'nvimx_stop', sub {
            $self->loop->stop;
        });
    })
}

has "api" => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        Neovim::RPC::API::AutoDiscover->new( rpc => $self );      
    },
);

before subscribe => sub($self,$event,@){
    $self->api->ready->done( sub{ $self->api->vim_subscribe( event => $event ) });
};

0 and around emit_request => sub {
    my( $orig, $self, @args ) = @_;
    my $event = $orig->($self,@args);
    $event->response->fail("no subscriber") unless $event->response->is_ready;
    $event;
};

has plugins => (
    is => 'ro',
    traits => [ 'Hash' ],
    isa => 'HashRef',
    default => sub { +{} },
);

# TODO make that a coerced type
# TODO can load an object directly
# TODO switch load_class for use_module
sub load_plugin ( $self, $plugin ) { 
    my $class = 'Neovim::RPC::Plugin::' . $plugin;

    return $self->plugins->{$plugin} ||=
        load_class($class)->new( rpc => $self );
}

1;

=head1 SEE ALSO

=over

=item L<http://neovim.io> - Neovim site

=item L<http://techblog.babyl.ca/entry/neovim-way-to-go> - blog entry introducing Neovim-RPC to the world.

=back

=cut
