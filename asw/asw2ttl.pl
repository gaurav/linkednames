#!/usr/bin/perl -w

use strict;
use warnings;

use v5.012;

use Getopt::Long;
use IO::HTML;
use RDF::Helper;
use HTML::TreeBuilder;
use HTML::TreeBuilder::XPath;

require "helper.pl"; # Pull in some helper code.

# GetOptions
my $flag_no_output = 0;
my $result = GetOptions("silent" => \$flag_no_output);

# What do our URIs look like?
my $OUTPUT_FILENAME =   "names.ttl";
my $OUTPUT_FORMAT =     "turtle";
my $ROOT_URI = "http://gaurav.github.com/linkednames/asw/$OUTPUT_FILENAME" . '#';
my $START_FROM =        100_000;

# Current publication details.
my $CURRENT_PUBLICATION = $ROOT_URI . "lit_asw5_6_2013";
my $CURRENT_PUBLICATION_PROPS = {
    'rdfs:label' => 'Amphibian Species of the World, 5.6',
    'dc:bibliographicCitation' => "Frost, Darrel R. 2013. Amphibian Species of the World: an Online Reference. Version 5.6 (9 January 2013). Electronic Database accessible at http://research.amnh.org/herpetology/amphibia/index.html. American Museum of Natural History, New York, USA.",
    'dc:creator' => "Darrel R. Frost",
    'taxmeon:publishedInYear' => 2013
};

# Code to autogenerate URIs for use.
sub uri_in($) {
    return $_[0] . ":" . ($START_FROM++);
}

# Set up RDF
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

# Define some properties in RDFS!

# prop:hasCanonicalName (taxmeon:ScientificName --> rdfs:Literal)
$rdf->hashref2rdf({
        'rdfs:label' => 'Has canonical name',
        'dc:description' => "Records the canonical name for a taxmeon:ScientificName",
        'rdfs:domain' => 'http://www.yso.fi/onto/taxmeon/ScientificName',
        'rdfs:range' => 'http://www.w3.org/2000/01/rdf-schema#Literal',
    }, $ROOT_URI . "prop_hasCanonicalName"
);

# Define this publication itself.
$rdf->hashref2rdf($CURRENT_PUBLICATION_PROPS, $CURRENT_PUBLICATION);

# Expect one or more filenames.
foreach my $filename (@ARGV) {
    my $tree = HTML::TreeBuilder::XPath->new();

    # These are xml files, but they're encoded in Latin-1
    # anyway. 
    say "Parsing '$filename' ...";
    $tree->parse_file(html_file($filename));
    say "File parsed.";

    # NOTE: please don't add_name with a reference unless you've labeled
    # the first reference (we need it for the 'sec.' bit).
    sub add_name($@) {
        my $name = shift;
        my @references = @_;

        state %defined_name_uri;
        state %defined_concept_uri;
        return ($defined_name_uri{$name}, $defined_concept_uri{$name})
            if(exists $defined_name_uri{$name});

        die "No references provided!" unless (0 < scalar @references);

        say "  Adding name: $name.";

        my $name_uri = uri_in('name');
        $rdf->assert_literal($name_uri, 'rdfs:label', $name);
        $rdf->assert_resource($name_uri, 'rdf:type', 'taxmeon:ScientificName');

        # Create a taxon concept.
        my $first_ref = $references[0];

        die "First reference has no label." 
            unless $rdf->exists($first_ref, 'rdfs:label');

        my $pub_name = [$rdf->get_triples($first_ref, 'rdfs:label')]
                ->[0] # Get the first triple
                ->[2]; # And then the object in the [subj, pred, obj].
        my $concept_name = "$name sec. $pub_name"; 
        my $concept_uri = uri_in('tc');
            
        $rdf->assert_literal($concept_uri, 'rdfs:label', $concept_name);
        $rdf->assert_resource($concept_uri, 'taxmeon:hasScientificName', $name_uri);

        say "    Taxon concept: $concept_name ($concept_uri)";
            
        foreach my $ref (@references) {
            $rdf->assert_resource($concept_uri, 'taxmeon:isPublishedIn', $ref);
            say "      Adding isPublishedIn: $ref";
        }

        # Canonical name?
        my $canonical_name = get_canonical_name($name);
        if(defined $canonical_name) {
            say "    Identified canonical name: '$canonical_name'.";  
            $rdf->assert_literal($name_uri, 'prop:hasCanonicalName', $canonical_name);
        }
 
        $defined_name_uri{$name} = $name_uri;
        $defined_concept_uri{$name} = $concept_uri;

        return ($name_uri, $concept_uri);
    }

    # What is the name we're processing?
    my $current_name = $tree->findvalue("//h2");
    my ($name_uri, $concept_uri) = add_name($current_name, $CURRENT_PUBLICATION);

    # TODO: $synonym is currently canonical, but we should turn it into
    # "Abc def Author, Year" for proper disambiguity.
    my @synonyms = $tree->findvalues('//div[@class="namelist"]//span[@class="taxon"]');
    foreach my $synonym (@synonyms) {
        # TODO: add other references as well?
        my ($syn_uri, $syn_concept_uri) = add_name($synonym, $CURRENT_PUBLICATION);
        $rdf->assert_resource($syn_concept_uri, "prop:hasAcceptedConcept", $concept_uri);
    }

    # Done!
    $tree->delete;
}

# Serialize into an output file in $OUTPUT_FORMAT/utf8.
say "Writing output to '$OUTPUT_FILENAME' ...";
open(my $fhout, '>:encoding(utf8)', $OUTPUT_FILENAME) or die "Could not open $OUTPUT_FILENAME for writing: $!";
my $output = $rdf->serialize(format => $OUTPUT_FORMAT);

# Prettify the output slightly.
$output =~ s[\.\n([^\s\@])][\.\n\n$1]g;

# This confuses Mulgara, so ...
$output =~ 
    s[\@base <http://gaurav.github.com/linkednames/asw/names.ttl#> .]
     [#\@base <http://gaurav.github.com/linkednames/asw/names.ttl#> .]g;


# Write it out.
print $fhout $output;

say "\n===OUTPUT===\n$output\n===END OUTPUT===\n\nGraph URI: $ROOT_URI\n"
    unless($flag_no_output);

close($fhout);
say "Output written (" . $rdf->count() . " statements).";
