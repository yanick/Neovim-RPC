package Neovim::RPC::API::Command;
our $AUTHORITY = 'cpan:YANICK';
$Neovim::RPC::API::Command::VERSION = '0.0.1';
use strict;
use warnings;

use Moose;
use MsgPack::Encoder;
use MsgPack::Type::Ext;

use List::Util qw/ pairmap /;

use experimental 'postderef';

has api => (
    is => 'ro',
);

has deferred => (
    is => 'ro',
    default => 1,
);

has name => (
    is => 'ro',
    required => 1,
);

has parameters => (
    traits => [ 'Array' ],
    isa => 'ArrayRef',
    is => 'ro',
    default => sub { [] },
    handles => { all_parameters => 'elements' },
);

has receives_channel_id => (
    is => 'ro',
);

has return_type => (
    is => 'ro',
);

sub args_to_struct {
    my( $self, %args ) = @_;

    [ 
        pairmap {
            my $type = $self->api->types->{$a};
            defined $type
                ? MsgPack::Type::Ext->new( type => $type, data => $b )
                : $b
        }
        map { $_->[0] => $args{$_->[1]} } $self->parameters->@* ]
}

sub encode {
    my $self = shift;
    my $struct = @_ == 1 ? shift : $self->to_struct(@_);

    return MsgPack::Encoder->new( struct => $struct );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Neovim::RPC::API::Command

=head1 VERSION

version 0.0.1

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
