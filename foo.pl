#!/usr/bin/perl 

use strict;
use warnings;

open my $fh, '>', 'output';

print qq{:echo "hello there"\n};

while(<>) {
    print $fh $_;
}


