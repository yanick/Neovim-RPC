use 5.22.0;

package Decoder;

use strict;
use warnings;

use Moose;

use experimental 'signatures', 'postderef';

has buffer => (
    is => 'rw',
    traits => [ 'Array' ],
    default => sub { [] },
    handles => {
        'has_buffer' => 'count',
        next => 'shift',
        all => 'elements',
        add_to_buffer => 'push',
    },
);

after all => sub {
    $_[0]->buffer([]);
};


has gen_next => (
    is =>  'rw',
    clearer => 'clear_gen_next',
    default => sub { 
        gen_new_value();
    }

);

sub read {
    my $self = shift;
    my @values = map { ord } map { split '' } @_;

    my $gen = $self->gen_next;

    for my $v ( @values ) {
        $gen = $gen->($v);

        if( ref $gen ne 'CODE' ) {
            $self->add_to_buffer($gen->[0]);
            $gen = gen_new_value();
        }
    }

    $self->gen_next($gen);
}

use Types::Standard qw/ Str ArrayRef Int Any InstanceOf Ref /;
use Type::Tiny;

my $MessagePackGenerator  = Type::Tiny->new(
    parent => Ref,
    name => 'MessagePackGenerator',
);

my @msgpack_types = (
    [ PositiveFixInt => sub { $_ <= 0x7f }, \&gen_positive_fixint ],
    [ FixArray => sub { $_ >= 0x90 and $_ <= 0x9f }, \&gen_fixarray ],
);

for my $t  ( @msgpack_types ) {
    $MessagePackGenerator = $MessagePackGenerator->plus_coercions(
        Type::Tiny->new(
            parent => Int,
            name => $t->[0],
            constraint => $t->[1],
        ) => $t->[2] ) 
}

sub gen_new_value { 
    sub { 
        $MessagePackGenerator->assert_coerce(shift);
    } 
}

sub gen_positive_fixint { [ $_ ] }

sub gen_fixarray {
    my $size  = $_ - 0x90;
    my @array;
    my $gen;

    return [ \@array ] if $size == 0;

    sub {
        my $byte = shift;

        $gen ||= gen_new_value();

        $gen = $gen->($byte);

        if ( ref $gen ne 'CODE' ) { # got a new value

            push @array, $gen->[0];
            $gen = undef;

            return [ \@array ] if @array == $size;
        }

        return __SUB__;
    }
}


1;

my $decoder = Decoder->new;
$decoder->read( join '', map { chr } 0x93, 1, 2, 3 );

use Data::Printer;
say $decoder->has_buffer;
p $decoder->next;
