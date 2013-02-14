#
# Helper code for asw2ttl.pl
#

use v5.012;

use strict;
use warnings;

my $START_FROM =        100_000;

# Code to autogenerate URIs for use.
sub uri_in($) {
    return $_[0] . ":" . ($START_FROM++);
}

sub print_rdf_helper_to_file_silently($$) {
    print_rdf_helper_to_file(@_, 1);
}

sub print_rdf_helper_to_file {
    my($rdf, $filename, $flag_no_output) = @_;
    $flag_no_output = 0 unless defined $flag_no_output;

    # Serialize into an output file in $OUTPUT_FORMAT/utf8.
    say "Writing output to '$filename' ...";
    open(my $fhout, '>:encoding(utf8)', $filename) 
        or die "Could not open $filename for writing: $!";
    my $output = $rdf->serialize(format => 'turtle');

    # Prettify the output slightly.
    $output =~ s[\.\n([^\s\@])][\.\n\n$1]g;

    # This confuses Mulgara, so ...
    $output =~ 
        s[\@base <(.*)> .]
        [#\@base <$1> .]g;


    # Write it out.
    print $fhout $output;

    say "\n===OUTPUT===\n$output\n===END OUTPUT===\n\n"
        unless($flag_no_output);

    close($fhout);
    say "Output written (" . $rdf->count() . " statements).";
}

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
