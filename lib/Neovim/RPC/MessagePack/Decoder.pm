package Neovim::RPC::MessagePack::Decoder;

use strict;
use warnings;

use Moose;

use Log::Contextual::Easy::Default;

use 5.20.0;

use experimental 'postderef';

has buffer => (
    is => 'rw',
    traits => [ 'Array' ],
    default => sub { [] },
    handles => {
        '_add_buffer' => 'push',
    },
);

sub add_to_buffer {
    my( $self, @data ) = @_;
    $self->_add_buffer( map { ord } map { split '', $_ } @data );
}

has next => (
    is => 'rw',
    clearer => 'clear_next',
    predicate => '_has_next',
);

has chain => (
    is => 'rw',
    default => sub { [] },
);

has need_more => (
    is => 'rw',
    default => 0,
);

has gen_next => (
    is =>  'rw',
    clearer => 'clear_gen_next',
    default => sub { 
        gen_new_value();
    }

);

sub get_next {
    my $self = shift;
    
    die "no next value yet\n" unless $self->has_next;
    my $next = $self->next;
    $self->clear_next;
    return $next;
}

sub has_next {
    my $self = shift;

    return 1 if $self->_has_next;

    while( defined( my $byte = shift @{ $self->buffer } ) ) {
        log_debug { sprintf "byte: %x\n", $byte };

        my $res = $self->gen_next->($byte);
        log_debug { $res };

        if( ref $res eq 'CODE' ) {
            $self->gen_next($res);
        }
        else {
            $self->next($res);
            $self->gen_next( gen_new_value() );
            return 1;
        }
    }

    return;
}

type MessagePackGenerator

PositiveFixedInt, sub { ..condition.. }, sub { ..generator };
    

sub gen_new_value { 
    sub {
    my( $byte ) = @_;

    if( $byte >= 0x90 and $byte <= 0x9f ) {
        return gen_fixed_array( $byte );
    }

    return gen_fixedmap($byte) if $byte >= 0x80 and $byte <= 0x8f;

    return gen_positive_fixedint($byte) if $byte <= 0x7f;

    return gen_array(2) if $byte == 0xdc;  # array16

    return gen_bin() if $byte == 0xc4;

    return gen_undef()  if $byte == 0xc0;

    return 0 if $byte == 0xc2;
    return 1 if $byte == 0xc3;

    die sprintf "I don't how to cope with %x", $byte;
}
} 

sub gen_undef { 
    log_trace { "type undef" };
    undef;
}

sub gen_bin {
    my $size;
    my $value;

    log_trace { "type bin" };

    sub {
        my $byte = shift;

        if( not defined $size ) {
            $size = $byte;
            log_trace { "of size $size" };
            return '' if $size == 0;
        }
        else {
            $value .= chr $byte;
            return $value unless --$size;
        }

        __SUB__;
    }
}

sub gen_array {
    my $size_to_read = shift;
    my $size = 0;
    my @array;
    my $gen;

    return sub {
        my $byte = shift;

        if( $size_to_read ) {
            $size = $byte + $size * 2 ** 8;
            $size_to_read--;
        }
        else {
            $gen ||= gen_new_value();

            $gen = $gen->($byte);

            unless ( ref $gen eq 'CODE' ) {
                push @array, $gen;
                $gen = undef;
                return \@array if @array == $size;
            }
        }

        return __SUB__;
    }
}

sub gen_fixedmap {
    my $size = 2*($_[0] - 0x80);
    my @values;

    log_trace {"type fixedmap of size $size" };

    return {} if $size == 0;

    my $gen;

    sub {
        my $byte = shift;

        $gen ||= gen_new_value();

        $gen = $gen->($byte);

        unless ( ref $gen eq 'CODE' ) {
            push @values, $gen;
            $gen = undef;
            
            return +{ @values } if @values == $size;
        }

        return __SUB__;
    }

}

sub gen_positive_fixedint {
    log_trace { "positive fixedint " . $_[0] } @_;
    return shift;
}

sub gen_fixed_array {
    my $size  = $_[0] - 0x90;
    my @array;
    my $gen;

    log_trace {"type fixedarray of size $size" };

    return \@array if $size == 0;

    sub {
        my $byte = shift;

        $gen ||= gen_new_value();

        $gen = $gen->($byte);

        unless ( ref $gen eq 'CODE' ) {
            log_trace { "NEW $gen" };
            push @array, $gen;
            Dlog_trace { "HAS $_" } \@array;
            $gen = undef;
            Dlog_trace { "value $_" } \@array;
            return \@array if @array == $size;
        }

        return __SUB__;
    }
}

1;

