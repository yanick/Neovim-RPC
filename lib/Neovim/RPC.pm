package Neovim::RPC;

use strict;
use warnings;

use Moose;
use IO::Socket::INET;
use Neovim::RPC::API::AutoDiscover;
use Neovim::RPC::MessagePack::Decoder;
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
    default => '127.0.0.1',
);

has "port" => (
    isa => 'Int',
    is => 'ro',
    required => 1,
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

has "decoder" => (
    isa => 'Neovim::RPC::MessagePack::Decoder',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;

        Neovim::RPC::MessagePack::Decoder->new;
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

sub loop {
    my $self = shift;
    my %args = @_;

    while (read($self->socket, my $buf, 1)) {
        $self->decoder->add_to_buffer($buf);
        while( $self->decoder->has_next ) {
            my $next = $self->decoder->get_next;
            $self->log_debug( [ "receiving %s" , $next ]);

            if ( $next->[0] == 1 ) {
                $self->log_debug( [ "it's a reply for %d", $next->[1] ] );
                if( my $callback =  $self->reply_callbacks->{$next->[1]} ) {
                    $DB::single = 1;
                    
                    $callback->{future}->done( $next );
                }
            }
            elsif( $next->[0] == 2 ) {
                $self->log_debug( [ "it's a '%s' event", $next->[1] ] );
                $self->emit( $next->[1], class => 'Neovim::RPC::Event', args => $next->[2] );     
            }

            return if $args{until} and $args{until}->();
        }
    }
}
    

1;



