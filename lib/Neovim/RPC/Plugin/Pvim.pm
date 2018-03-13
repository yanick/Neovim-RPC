package Neovim::RPC::Plugin::Pvim;

use 5.20.0;

use strict;
use warnings;

use Path::Tiny;

use Neovim::RPC::Plugin::Pvim::Node;

use Neovim::RPC::Plugin;

use experimental 'signatures', 'postderef';

subscribe pvim_section => rpcrequest 
    sub ( $self, $event ) {
        my( $from_line, $to_line ) = $event->all_params;

        my %props = (
            from_line => $from_line - 1,
            to_line   => $to_line,
            buffer_id => $self->shall_get_current_buffer_id,
        );

        $props{lines} = collect_props(%props)->then(sub{
                $self->shall_get_buffer_lines($_[0]->%*)
        });
        

        return collect_props( %props );
    },
    sub ($self,$props) {
        my %props = %$props;
        my @items = $props{lines}->@*;

        $items[0] =~ /^(\s*)/;
        my $spaces = $1;

        s/^\s*// for @items;

        my $common = path($items[0])->parent;

        for my $item ( @items ) {
            $common = $common->parent until $common->subsumes($item);
        }

        @items = map { $spaces . $_ } 
            "$common Files=$common {",
                ( map { '  ' . path($_)->relative($common) } @items ),
            '}';

        $self->shall_set_lines_in_buffer(%props, lines => \@items);
    }, { catch => sub { warn $_[1]; } };

sub shall_get_current_buffer_id($self) {
    $self->api->vim_get_current_buffer
        ->then(sub{ ord $_[0]->data } )
}

sub shall_get_buffer_lines ($self,%props) {
    $self->api->buffer_get_lines(
        $props{buffer_id},
        $props{from_line}    // 0,
        $props{to_line}      // 1_000_000,
        $props{strict_lines} // 0 
    );
}

sub shall_set_lines_in_buffer ($self,%props) {
    $self->api->buffer_set_lines(
        $props{buffer_id},
        $props{from_line}    // 0,
        $props{to_line}      // 1_000_000,
        $props{strict_lines} // 0, 
        $props{lines}        // [],
    );
}

subscribe pvim_update => rpcrequest sub( $self, @ ) {
    my %props = (
        buffer_id => $self->shall_get_current_buffer_id, 
    );

    my $file;

    $self->api->vim_command( 'write' )
        ->then(sub{
            $self->api->vim_call_function( 
                fname => 'expand', args => [ '%:p' ] );
        })
        ->then( sub { 
            $file = path(shift);
            [ $file->lines ]
        } )
    ->then(sub{ 
        my @lines = $_[0]->@*;
        my $node = ( grep { /project=/ } @lines ) 
            ? Neovim::RPC::Plugin::Pvim::Node->parse(@lines)
            : Neovim::RPC::Plugin::Pvim::Node->new( location => $file->parent->parent )
            ;

        $file->spew( map { $_, "\n" } $node->update->print );
        $self->api->vim_command( 'e' );
    })

};


sub collect_props {

    use Promises qw/ deferred /;
    my %promises = @_;

    my $all_done  = deferred();

    my $results   = {};
    my $remaining = scalar keys %promises;

    my $are_we_there_yet = sub {
        return if --$remaining;

        return if $all_done->is_rejected;

        $all_done->resolve($results);
    };

    while( my( $key, $promise ) = each %promises ) {
        unless( ref $promise eq 'Promises::Promise' or ref $promise eq 'Promises::Deferred' ) {
            my $p = deferred();
            $p->resolve($promise);
            $promise = $p;
        }

        $promise->then(sub{ $results->{$key} = shift })
            ->then( $are_we_there_yet, sub { $all_done->reject(@_) } );
    }

    return $all_done->promise;
}

1;
