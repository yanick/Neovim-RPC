use strict;
use warnings;

use Test::More tests => 1;
use Test::Deep;

use MessagePack::Encoder;

sub encode {
    [ map { sprintf "%x", ord } split '', MessagePack::Encoder->new(struct => shift) ]
};

sub cmp_encode(@){
    my( $struct, $wanna, $comment ) = @_;
    cmp_deeply( encode($struct) => $wanna, $comment );
}

cmp_encode 15 => [ 0x15 ], "number 15";

