#!/usr/bin/perl 

use strict;
use warnings;

open my $fh, '<', 'data';

my $text = join '',<$fh>;

my @bytes = unpack 'C*', $text;

use Data::Printer;
#print join " ", @bytes;


package Streamer;

use Moo;

use Log::Contextual::Easy::Default;

use 5.20.0;

use experimental 'postderef';

has buffer => (
    is => 'rw',
);

has next => (
    is => 'rw',
);

has _has_next => (
    is => 'rw',
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

sub has_next {
    my $self = shift;

    return 1 if $self->_has_next;

    while( defined( my $byte = shift @{ $self->buffer } ) ) {
        log_debug { sprintf "byte: %x\n", $byte };

        my $res = $self->gen_next->($byte);

        if( ref $res eq 'CODE' ) {
            $self->gen_next($res);
        }
        else {
            $self->_has_next(1);
            $self->next($res);
            $self->clear_gen_next;
            return 1;
        }
    }

    return;
}

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
    my $size;
    my @array;
    my $gen;

    warn "\tnew array\n";

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

sub foo {
    my $self;
    my $first;
    if ( @{ $self->chain } and $self->need_more <=0 ) {
        $self->_next( $self->compile_chain );
        return 1;
    }
        warn "it's a fixarray\n";
        my $length = $first - 0x90;
        warn "of length $length";

        push @{ $self->{chain} }, [ array => $length ];
        $self->need_more( $self->need_more + $length );

    $first = shift @{ $self->buffer };
    warn sprintf "%x %s", $first, $self->need_more;
    
    my @chain = @{$self->chain};

    if( @chain and ref $chain[-1] and $chain[-1][0] eq 'bin' and @{$chain[-1]} == 1 ) {
        warn "uh uh";
        $self->chain->[-1][1] = $first;
        $self->need_more( $self->need_more + $first -1 );
    }
    elsif ( @chain and ref $chain[-1] and $chain[-1][0] eq 'array16' and @{$chain[-1] } < 3) {
        push @{ $self->chain->[-1] }, $first;
        if ( $self->chain->[-1]->@* == 3 ) {
            warn $self->chain->[-1][2];
            $self->need_more( $self->need_more -1 + $self->chain->[-1][1] * 2**8 + $self->chain->[-1][2] );
        }
    }
    elsif( $first == 0xdc ) {
        push @{ $self->{chain} }, [ 'array16' ];
    }
    elsif( $first >= 0x90 and $first <= 0x9f ) {
        warn "it's a fixarray\n";
        my $length = $first - 0x90;
        warn "of length $length";

        push @{ $self->{chain} }, [ array => $length ];
        $self->need_more( $self->need_more + $length );

    }
    elsif( $first == 0xc2 ) {
        push @{ $self->{chain} }, 0;
        $self->need_more($self->need_more-1);
    }
    elsif( $first == 0xc3 ) {
        push @{ $self->{chain} }, 1;
        $self->need_more($self->need_more-1);
    }
    elsif( $first == 0xc0 ) {
        push @{ $self->{chain} }, undef;
    }
    elsif( $first >= 0x80 and $first <= 0x8f ) {
            warn "fixmap";
            my $length = $first - 0x80;
        push @{ $self->{chain} }, [ hash => 2*$length ];
        $self->need_more( $self->need_more + 2*$length );
    }
    elsif ( $first == 0xc4 ) {
        warn "bin";
        push @{ $self->{chain} }, [ 'bin' ];

    }
    else {
        die sprintf "I don't know what %x is", $first;
    }

    return &has_next($self);


}

sub compile_chain {
    my $self = shift;
    use Data::Printer;
    die p $self->chain;
}


my $streamer = Streamer->new;
$streamer->buffer(\@bytes);

say $streamer->has_next;

p $streamer->next;

#$streamer->compile_chain;
