package Neovim::RPC::Plugin::Pvim::Node; 

use 5.20.0;

use strict;
use warnings;

use Moose;

use Types::Path::Tiny qw/Path AbsPath/;

use List::AllUtils qw/ any uniq /;
use Data::Printer;
use Set::Object;
use Path::Tiny;
use Text::Balanced qw/ extract_bracketed /;
use List::UtilsBy qw/ nmax_by /;

with 'Beam::Emitter';

use experimental 'signatures', 'postderef';

has _file_cache => (
    is => 'ro',
    default => sub { 
        +{}
    },
);

has project_file => (
    is => 'ro',
    default => sub { '.git/vim.project' },
    isa => Path,
    coerce => 1,
);

sub has_project_file($self) {
    return $self->project_file->is_file;
}

has name => (
    is => 'rw',
    lazy => 1,
    default => sub { $_[0]->location },
);

has 'location' => (
    is => 'rw',
    isa => Path,
    default => sub { '.' },
    coerce => 1,
);

has abs_path => (
    is => 'ro',
    lazy => 1,
    default => sub($self) {
        $self->is_root ? $self->location->absolute : $self->parent->abs_path->child($self->location);
    },
    handles => [ 'subsumes' ],
);

has parent => (
    is => 'ro',
);

sub is_root($self) { !$self->parent }

sub root($self) { 
    $self->is_root ? $self : $self->parent->root;
}


has subnodes => (
    is => 'ro',
    default => sub { [] },
    traits => [ 'Array' ],
    handles => { all_subnodes => 'elements', 'add_subnode' => 'push' },
);

after add_subnode => sub( $self, $subnode ) {
    for my $event ( qw/ add_file / ) {
        $subnode->subscribe( $event, sub { 
            $self->emit_args( $event, @_ );
        } );
    }
};

has files => (
    is => 'rw',
    default => sub { [] },
    traits => [ 'Array' ],
    handles => { all_files => 'elements', 'push_file' => 'push' },
);

sub add_file($self,$file) { 
    $file = $self->abs_path->child($file) unless ref $file;

    $self->push_file( $file ) 
}

after push_file => sub($self,$file) {
    $self->root->_file_cache->{ $file->absolute } = 1;
};

after add_file => sub($self,$file) {
    $self->emit_args( add_file => $self, $file );
};

has ignores => (
    is => 'ro',
    default => sub { [] },
    traits => [ 'Array' ],
    handles => { all_ignores => 'elements', push_ignore => 'push' },
);

sub add_ignore($self,$ignore) {
    $self->push_ignore( $ignore );
}

sub update($self) {
    local $RPC::Plugin::Pvim::Node::NBR_FILES = 0;
    $self->add_new_files;

    $self->remove_filtered();

    return $self;
}

sub remove_filtered($self) {
    $self->files([
        grep { ! $self->root->should_ignore($_) } $self->all_files
    ]);
    $_->remove_filtered for $self->all_subnodes;
}

sub add_new_files($self,$dir=undef) {

    $dir ||= $self->abs_path;

    CHILD:
    for my $child ( $dir->children ) {
        next if $self->should_ignore($child);

        if ( $RPC::Plugin::Pvim::Node::NBR_FILES++ > 1_000 ) {
            last CHILD;
        }

        if( $child->is_dir ) {
            $self->add_new_files($child);
            next;
        }

        next if $self->root->_file_cache->{ $child->absolute };

        for my $node ( $self->all_subnodes, $self ) {
            next unless $node->subsumes($child);
            $node->add_file($child);
            last;
        }
    }

}

sub already_present($self,$file) {
    return any { $_ eq $file } $self->all_files;
}

sub can_contain($self,$file) {
    return unless $self->subsumes($file);
    return $self, map { $_->can_contain($file) } $self->all_subnodes;
}

sub parse($self,@doc) {
    $self = $self->new unless ref $self;

    my $doc = join "\n", @doc;

    my( $inner, undef, $leading ) = extract_bracketed( $doc, '{', qr/[^\{]*/ );

    if( $self->is_root ) {
        $DB::single = 1;
        $leading =~ /project=(\S+)\s+CD=(\S+)/;
        $self->name($1);
        $self->location($2);
    }

    $doc = $inner =~ s/\{(.*)\}/$1/sr;
    while( $doc =~ s/^(.+)//m ) {
        my $line = $1;
        next if $line =~ /^\s*$/;
        if ( $line =~ s/^\s*#!\s*// ) {
            $self->add_ignore($line);
        } 
        elsif( $line =~ /\{/ ) {
            ( $inner, $doc, $leading ) = extract_bracketed( $line.$doc, '{', qr/[^\{]*/ );
            $leading =~ /(\S+)\s+Files=(\S+)/;
            my $subnode = __PACKAGE__->new( name => $1, location => $2, parent => $self );
            $subnode->parse($inner);
            $self->add_subnode($subnode);
        }
        else {
            $line =~ s/^\s+|\s+$//m;
            $line =~ s/^#\s*//;
            $self->add_file( $line );
        }
    }

    return $self;
}

sub print($self) {
    $self->is_root ? $self->print_project : $self->print_node;
}

sub print_project($self) {
    return sprintf( "project=%s CD=%s {",
        $self->name, $self->location->stringify, $self->location->stringify ),
    $self->print_children, '}';
}

sub print_children($self) {
    return(
        ( map { 
            ( '#'x!$_->is_file ) .
            $_->relative($self->abs_path) 
        } $self->all_files),
        ( map { $_->print_node } $self->all_subnodes ),
        ( map { "#! " . $_ } $self->all_ignores )
    );
}

sub print_node($self) {

    return sprintf( "%-20s Files=%s {",
        $self->name, $self->location ),
        ( map { '  ' . $_ } $self->print_children ),
        '}';
}

sub should_ignore($self,$file){

    return unless $self->subsumes($file);

    my $segment = $file->relative($self->abs_path);

    return any { $segment =~ /^$_/ } $self->all_ignores;

}

1;
