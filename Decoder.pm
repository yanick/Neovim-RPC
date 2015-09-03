use 5.22.0;

package Decoder;

use strict;
use warnings;

use Moose;

use List::AllUtils qw/ first first_index any /;

use List::Gather;

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

after all => sub($self) {
    $self->buffer([]);
};


has gen_next => (
    is =>  'rw',
    clearer => 'clear_gen_next',
    default => sub { 
        gen_new_value();
    }

);

sub is_gen($val) { ref $val eq 'CODE' }

sub read($self,@values) {

    @values = map { ord } map { split '' } @values;

    my $gen = $self->gen_next;

    $self->add_to_buffer($_) for gather {
        for ( @values ) {
            $gen = $gen->($_);
            
            next if is_gen($gen);

            take $gen->[0];

            $gen = gen_new_value();
        }
    };

    $self->gen_next($gen);
}

use Types::Standard qw/ Str ArrayRef Int Any InstanceOf Ref /;
use Type::Tiny;

my $MessagePackGenerator  = Type::Tiny->new(
    parent => Ref,
    name   => 'MessagePackGenerator',
);

my @msgpack_types = (
    [ PositiveFixInt => [    0, 0x7f ], \&gen_positive_fixint ],
    [ FixArray       => [ 0x90, 0x9f ], \&gen_fixarray ],
);

$MessagePackGenerator = $MessagePackGenerator->plus_coercions(
    map {
        my( $min, $max ) = $_->[1]->@*;
        Type::Tiny->new(
            parent     => Int,
            name       => $_->[0],
            constraint => sub { $_ >= $min and $_ <= $max },
        ) => $_->[2]  
    } @msgpack_types
);

sub gen_new_value { 
    sub ($byte) { $MessagePackGenerator->assert_coerce($byte); } 
}

sub gen_positive_fixint { [ $_ ] }

sub gen_fixarray {
    gen_array( $_ - 0x90 );
}

sub gen_array($size) {

    return [ [] ] unless $size;

    my @array;

    @array = map { gen_new_value() } 1..$size;

    sub($byte) {
        $_ = $_->($byte) for first { is_gen($_) } @array;

        ( any { is_gen($_) } @array ) ? __SUB__ : [ \@array ];
    }
}


1;

my $decoder = Decoder->new;
$decoder->read( join '', map { chr } 0x93, 1, 2, 3 );

use Data::Printer;
say $decoder->has_buffer;
p $decoder->next;
