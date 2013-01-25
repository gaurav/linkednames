#
# Helper code for asw2ttl.pl
#

use v5.012;

use strict;
use warnings;

sub get_canonical_name($) {
    my $name = shift;

    if($name =~ /^\s*([A-Z][a-z]+) ([a-z]+)(?: ([a-z]+))?\b/) {
        my $binom = "$1 $2";
        if(defined $3) {
            return "$binom $3";
        } else {
            return $binom;
        }
    }

    return undef;
}

1;
