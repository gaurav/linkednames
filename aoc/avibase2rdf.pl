#!/usr/bin/perl -w

=head1 NAME

avibase2rdf.pl -- A script for converting an Avibase diff to RDF

=head1 SYNOPSIS

    perl avibase2rdf.pl [--source "<uri>"] html/avibase-downloaded-html.html > output.rdf

=cut

use v5.012;

use strict;
use warnings;

use Text::CSV;
use RDF::Helper;
use Getopt::Long;

require "helper.pl";

my $OUTPUT_FILENAME =   "data/changes.ttl";
my $OUTPUT_FORMAT =     "turtle";
my $ROOT_URI = "http://gaurav.github.com/linkednames/aoc/$OUTPUT_FILENAME" . '#';

my $rdf = RDF::Helper->new(
    namespaces => {
        # Standard ones.
        rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        rdfs => "http://www.w3.org/2000/01/rdf-schema#",
        dc => 'http://purl.org/dc/terms/',

        # The ones we need.
        taxmeon => 'http://www.yso.fi/onto/taxmeon/',
        rank => 'http://purl.obolibrary.org/obo/taxrank.owl#',

        # Our namespaces.
        prop => $ROOT_URI . "prop_",    # properties we define
        tc =>   $ROOT_URI . "tc_",      # taxon concepts
        name => $ROOT_URI . "name_",    # names
        lit =>  $ROOT_URI . "lit_",     # reference to literature
        ns =>   $ROOT_URI . "name_status_",
    },
    ExpandQNames => 1,
    base_uri => $ROOT_URI
);

# Load up some standard definitions.
use RDF::Trine::Parser;

my $parser = RDF::Trine::Parser->new('turtle');
$parser->parse_file_into_model($ROOT_URI, 'header.ttl', $rdf->model());

my $diff_source = "";

my $result = GetOptions(
    "source=s" => \$diff_source
);

foreach my $filename (@ARGV) {
    if(!-e $filename) {
        warn "Filename '$filename' could not be found, skipping.";
        next;
    }

    $diff_source = URI::file->new($filename)
        unless defined $diff_source;

}

# Write output.
print_rdf_helper_to_file($rdf, $OUTPUT_FILENAME);
# print_rdf_helper_to_file_silently($rdf, $OUTPUT_FILENAME);

say "\nGraph URI: $ROOT_URI.";
