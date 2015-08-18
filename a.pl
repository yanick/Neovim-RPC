#!/usr/bin/perl 

use strict;
use warnings;

my $file = '/tmp/nvimOYNmll/0';

use IO::Socket::INET;
use Data::Printer;
use Data::MessagePack::Stream;
use Data::MessagePack;

use Neovim::RPC::MessagePack::Encoder;
use Neovim::RPC::MessagePack::Decoder;

my $packet = Neovim::RPC::MessagePack::Encoder->new( struct => [ 0, 1, 'vim_get_api_info',[] ] );
my $decoder = Neovim::RPC::MessagePack::Decoder->new;

my $socket = IO::Socket::INET->new('127.0.0.1:6666');

use Neovim::RPC::API::Command;
use Neovim::RPC::API;

use Neovim::RPC;

my $rpc = Neovim::RPC->new(
    port => 6666,
);

$rpc->add_listener( 
    'connect' => sub {
        my $rpc = shift;
        $rpc->api->vim_get_api_info(
            callback => sub {
                my( $rpc, $answer ) = @_;
                use Data::Printer;
                p $answer;
            },
        )
    },
);

$rpc->start;

__END__



my $api = Neovim::RPC::API->new;
$api->add_command( {
    name => 'vim_get_api_info',
});

$packet = $api->vim_get_api_info( _id => 11 );

#::Command->new(
#    name => 'vim_get_api_info',
#)->encode( );

$socket->send( $packet );

$| = 1;
while (read($socket, my $buf, 1)) {
    $decoder->add_to_buffer($buf);
    while( $decoder->has_next ) {
        use Data::Printer;
    p $decoder->get_next;
    }
}

__END__

my $unpacker = Data::MessagePack::Stream->new;

my $packer = Data::MessagePack->new;

my $packet = chr(0x94) . chr(0) . chr(0x01) . chr(0xa0 + 9 ) . 'vim_input'
        .chr(0x91)
        . chr(0xa0 + 5 ) . "ihell";
'x'        .chr(0x93) 
        . chr(0xd4) . chr(0x00) . chr(0x01)
        . chr(0x01)
        . chr(0x91) . chr( 0xa0 +6 ) ."hello\n";

$socket->send( $packet );
print $packet, "\n";
print $packer->pack(
       [ 0, 1, 'buffer_insert', [0,1,["hello\n"]] ]
    );
 
exit;
open my $fh, '>', 'data';
while (read($socket, my $buf, 10024)) {
    print $buf;
    print $fh $buf;
    $unpacker->feed($buf);
    #print $buf;
 
    while ($unpacker->next) {
        use 5.20.0;
        say $unpacker->data;
    }
}
