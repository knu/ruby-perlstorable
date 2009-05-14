#!/usr/bin/perl

use strict;
use warnings;
use Storable;
use Data::Dumper;

my $code = do {
    if (@ARGV > 0) {
        join(';', @ARGV);
    } else {
        local $/ = undef;
        scalar <>;
    }
};

my $value = eval $code;

if ($@) {
    print STDERR "$@\n";
    exit 1
}

my $object = ref($value) ? $value : \$value;

print Storable::nfreeze($object);
