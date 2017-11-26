package Neovim::RPC::Plugin::FlipOperator;

use 5.20.0;

use strict;
use warnings;

=head1 SYNOPSIS

in F<init.vim>

    function! Perl_flipOperator() range
        call rpcrequest( g:nvimx_channel, 'flip_operator', a:firstline, a:lastline, getline( a:firstline, a:lastline ) )
    endfunction

    au FileType perl map  <buffer> <leader>fo (v):call Perl_flipOperator()<CR>
    au FileType perl vmap <buffer> <leader>fo :call Perl_flipOperator()<CR>

=cut

use Neovim::RPC::Plugin;

use Promises qw/  deferred collect_hash /;

use experimental 'postderef', 'signatures';

subscribe flip_operator => #rpcrequest
    sub( $self, $event ) { 
        my( $from, $to, $code ) = $event->all_params;

        collect_hash( 
            from      => $from,
            to        => $to,
            code      => [ split "\n", $self->flip_snippet(join "\n", @$code ) ],
            buffer_id => $self->rpc->api->vim_get_current_buffer->then( sub { ord $_[0]->data } )
        );
    }, 
    sub ($self,%c) {
         $self->rpc->api->buffer_set_lines(  
             $c{buffer_id}, $c{from}-1, $c{to}, 1, $c{code}
         ) 
    };

sub flip_snippet($self,$snippet) {


    $snippet =~ s/^\s*\n//gm;
    my ($indent) = $snippet =~ /^(\s*)/;
    $snippet =~ s/^$indent//gm;

    my $operators = join '|', qw/ if unless while for until /;

    my $block_re = qr/
        ^
        (?<operator>$operators)
            \s* (?:my \s+ (?<variable>\$\w+) \s* )?
            \( \s* (?<array>[^)]+) \) \s* {
                (?<inner>.*)  
            }
            \s* $
    /xs;

    my $postfix_re = qr/
        ^
        (?<inner>[^;]+?) 
        \s+ (?<operator>$operators) 
        \s+ (?<array>[^;]+?) 
        \s* ;
        $
    /xs;

    if ( $snippet =~ $block_re ) {
        $snippet = block_to_postifx( $snippet, %+ );
    }
    elsif( $snippet =~ $postfix_re ) {
        $snippet = postfix_to_block( $snippet, %+ );
    }

    warn $snippet;
    $snippet =~ s/^\s*?\n//;

    $snippet =~ s/^/$indent/gm;

    return $snippet;
}

sub postfix_to_block {
    my( $snippet, %capture ) = @_;

    $snippet = $capture{inner};
    chomp $capture{array};
    $snippet = "$capture{operator} ( $capture{array} ) {\n    $snippet\n}";

}

sub block_to_postifx {
    my( $snippet, %capture ) = @_;

    # more than one statement? Don't touch it
    return $snippet if $capture{inner} =~ /(;)/ > 1;

    $snippet = $capture{inner};
    $snippet =~ s/;\s*$//; 

    $snippet =~ s/\Q$capture{variable}/\$_/g;
    $snippet =~ s/\$_\s*=~\s*//g;

    $capture{array} =~ s/\s*$//;

    $snippet .= " $capture{operator} $capture{array};";

    return $snippet;
}

1;
