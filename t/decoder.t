use strict;
use warnings;

use Test::More tests => 1;                      # last test to print

use MessagePack::Decoder;

my $decoder = MessagePack::Decoder->new(
    debug => 1,
    log_to_stderr => 1,
);

$decoder->read(
    "\x83\xc4\tfunctions\x02\x03\x04\x05\x06"
);

is_deeply $decoder->next => {
    'functions' => 2,
    3 => 4,
    5 => 6,
};

$decoder->read(
    "\x81\xc4\tfunctions\x81\xc4\tfunctions\x03"
);

is_deeply $decoder->next => {
    'functions' => { functions => 3 }
};

$decoder->read(
    "\x81\xc4\tfunctions\x91\xc4\tfunctions"
);

is_deeply $decoder->next => {
    'functions' => [ 'functions' ]
};

$decoder->read(
    "\xdc\x00\x02\x09\x08"
);

is_deeply $decoder->next => [ 9, 8 ];
