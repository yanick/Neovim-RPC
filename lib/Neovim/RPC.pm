package Neovim::RPC;
# ABSTRACT: RPC client for Neovim

use strict;
use warnings;

use Moose;
use IO::Socket::INET;
use MessagePack::RPC;
use Neovim::RPC::API::AutoDiscover;
use MessagePack::Decoder;
use Neovim::RPC::Event;
use Future;

use experimental 'signatures';

with 'Beam::Emitter';
with 'MooseX::Role::Loggable' => {
    -excludes => [ 'Bool' ],
};

has "host" => (
    isa => 'Str',
    is => 'ro',
    lazy => 1,
    default => sub { ( split ':', $_[0]->nvim_listen_address )[0] },
);

has nvim_listen_address => (
    is => 'ro',
    default => sub { $ENV{NVIM_LISTEN_ADDRESS} },
);

has "port" => (
    isa => 'Int',
    is => 'ro',
    lazy => 1,
    default => sub { ( split ':', $_[0]->nvim_listen_address )[1] },
);

has "socket" => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;

        my $addie = join ':', $self->host, $self->port;

        IO::Socket::INET->new( $addie )
            or die "couldn't connect to $addie";
    },
);

has decoder => (
    isa => 'MessagePack::Decoder',
    is => 'ro',
    lazy => 1,
    default => sub {
        MessagePack::Decoder->new(
            logger => $_[0]->logger
        );
    },
);

has "api" => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        Neovim::RPC::API::AutoDiscover->new( rpc => $self, logger => $self->logger );      
    },
);

has "reply_callbacks" => (
    is => 'ro',
    lazy => 1,
    default => sub {
        {};
    },
);

sub add_reply_callback {
    my( $self, $id ) = @_;
    my $future = Future->new;
    $self->reply_callbacks->{$id} = {
        timestamp => time,
        future => $future,
    };

    $future;
}

before subscribe => sub($self,$event,@){
    $self->api->vim_subscribe( event => $event );
};

sub send($self,$struct) {
    $self->log( [ "sending %s", $struct] );

    my $encoded = MessagePack::Encoder->new(struct => $struct)->encoded;

    $self->log_debug( [ "encoded: %s", $encoded ] );
    $self->socket->send($encoded);
}

sub loop {
    my $self = shift;
    my %args = @_;

    while (read($self->socket, my $buf, 1)) {
        $self->decoder->read($buf);
        while( $self->decoder->has_buffer ) {
            my $next = $self->decoder->next;
            $self->log( [ "receiving %s" , $next ]);

            if ( $next->[0] == 1 ) {
                $self->log_debug( [ "it's a reply for %d", $next->[1] ] );
                if( my $callback =  $self->reply_callbacks->{$next->[1]} ) {
                    my $f = $callback->{future};
                    $next->[2] 
                        ? $f->fail($next->[2])
                        : $f->done($next->[3])
                        ;
                }
            }
            elsif( $next->[0] == 2 ) {
                $self->log_debug( [ "it's a '%s' event", $next->[1] ] );
                $self->emit( $next->[1], class => 'Neovim::RPC::Event', args => $next->[2] );     
            }
            elsif( $next->[0] == 0 ) {
                $self->log_debug( [ "it's a '%s' request", $next->[2] ] );
                $self->emit( $next->[2], class => 'Neovim::RPC::Event', args => $next->[3],
                    event_id => $next->[1] );     
            }

            return if $args{until} and $args{until}->();
        }
    }
}
    

1;



