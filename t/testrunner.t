use strict;
use warnings;

use lib 't/lib';

use Test::Class::Moose::Load qw(t/tests);
use Test::Class::Moose::Runner;

Test::Class::Moose::Runner->new->runtests;

