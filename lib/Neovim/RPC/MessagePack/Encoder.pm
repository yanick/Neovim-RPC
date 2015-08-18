package Neovim::RPC::MessagePack::Encoder;

use strict;
use warnings;

use Moo;

use experimental 'postderef';

use overload '""' => \&encoded;

use Types::Standard qw/ Str ArrayRef Int Any InstanceOf /;
use Type::Tiny;

my $PositiveFixInt = Type::Tiny->new(
    parent => Int,
    name => 'PositiveFixint',
    constraint => sub { $_ >= 0 and $_ < 2*8-1 },
);

my $Str8 = Type::Tiny->new(
    parent => Str,
    name => 'Str8',
    constaints => sub { length $_ <= 2**8 - 1 }
);

my $FixStr = Type::Tiny->new(
    parent => $Str8,
    name => 'FixStr',
    constaints => sub { length $_ <= 31 }
);

my $FixArray = Type::Tiny->new(
    parent => ArrayRef,
    name => 'FixArray',
    constraints => sub { @$_ < 31 },
);


my $MessagePack = Type::Tiny->new(
    parent => InstanceOf['MessagePacked'],
    name => 'MessagePack',
)->plus_coercions(
    $PositiveFixInt      ,=> \&encode_positive_fixint,
    $FixStr ,=> \&encode_fixstr,
    $Str8 ,=> \&encode_str8,
    $FixArray ,=> \&encode_fixarray,
);

has struct => (
    isa => $MessagePack,
    is => 'ro',
    required => 1,
    coerce => 1,
);

sub BUILDARGS {
    shift;
    return { @_ == 1 ? ( struct => $_ ) : @_ };
}

sub encoded {
    my $self = shift;
    $self->struct->$*;
}

sub _packed($) {
    my $value = shift;
    bless \$value, 'MessagePacked';
}

sub encode_str8 {
    my $string = shift;
    _packed chr( 0xd9 ) . chr( length $string ) . $string;
}

sub encode_fixstr {
    my $string = shift;
    _packed chr( 0xa0 + length $string ) . $string;
}

sub encode_positive_fixint {
    my $int = shift;

    _packed chr $int;
}

sub encode_fixarray {
    my @inner = @{ shift @_ };
    
    my $size = @inner;

    _packed join '', chr( 0x90 + $size ), map {
        Neovim::RPC::MessagePack::Encoder->new( $_ )
    } @inner;
}


1;


