#!/usr/bin/perl -w

use v5.0010;

use strict;
use warnings;

use utf8;
use Text::CSV;

use DBI;
use DBD::Pg;

our $DBNAME = "gbifnub";
our $TBNAME = "taxon";
our $TAXONID_FIELD = "id";      # taxonid
our $SCIENTIFICNAME_FIELD = "canonicalname"; 

# Read CSV file.
die "No filename provided!" unless defined $ARGV[0];
my $filename = $ARGV[0];

open(my $csvfile, '<:encoding(utf8)', $filename) or die "Could not open $filename for reading.";
my $csv = Text::CSV->new({
    binary => 1,
    allow_whitespace => 1
});
$csv->column_names($csv->getline($csvfile));

# Get to the database.
say "Connecting to database $DBNAME ...";

my $dbh = DBI->connect("dbi:Pg:dbname=$DBNAME;port=5433", "gaurav", "", {
    RaiseError => 1
});

my @results = $dbh->selectrow_array("SELECT COUNT(*) AS total_count FROM $TBNAME");
    # COUNT(DISTINCT scientificname) AS count_sn FROM $TBNAME");
my $num_names = $results[0];
# my $num_uniq = $results[1];

say "Using $DBNAME, containing $num_names names.";
    # ($num_uniq unique).";

my $count_input_names = 0;
my $count_matched = 0;
my $count_not_matched = 0;
my $count_not_parsed = 0;

my %unmatched_providers;
my %unmatched_dataset_id;
my %unmatched_monomial;
my %unmatched_genera;
my %reasons;

while(not eof($csvfile)) {
    my $line = $csv->getline_hr($csvfile);
    
    if(not defined $line) {
        $count_not_parsed++;
        say STDERR "Could not parse line '" . $csv->string() . "': " . $csv->error_diag();
        next;
    }

    my %fields = %{$line};
    my $name = $fields{'scientificname'};
    my $provider = $fields{'provider'};
    my $dataset_id = $fields{'dataset_id'};

    $count_input_names++;
    
    # die "Name: '$name'";

    my $query = "SELECT $TAXONID_FIELD FROM $TBNAME WHERE $SCIENTIFICNAME_FIELD = ?";
    my $results = $dbh->selectrow_arrayref($query, {}, $name);

    if(not defined $results) {
        $count_not_matched++;

        $unmatched_providers{$provider} = 0     if(not exists $unmatched_providers{$provider});
        $unmatched_dataset_id{$dataset_id} = 0  if(not exists $unmatched_dataset_id{$dataset_id});

        $unmatched_providers{$provider}++;
        $unmatched_dataset_id{$dataset_id}++;

        # Some reasons why $name didn't match.
        my $reason;
        given($name) {
            when(/\bspp\.?\b/)  { $reason = "spp"; }
            when(/\bsp\.?\b/)   { $reason = "sp"; }
            when(/\bcf\.?\b/)   { $reason = "cf"; }
            when(/\?/)          { $reason = "contains_question_mark"; }
            when(utf8::is_utf8($_)) 
                                { $reason = "contains_utf8"; }
            default             { $reason = "unknown"; }
        }

        my ($genus, $epithet, $trinomial) = split(/\s+/, $name);
        if(defined($epithet) and not defined($trinomial)) {
            $unmatched_genera{$genus} = {}              unless exists $unmatched_genera{$genus};
            $unmatched_genera{$genus}{$epithet} = []     unless exists $unmatched_genera{$genus}{$epithet};
            push @{$unmatched_genera{$genus}{$epithet}}, "$provider/$dataset_id";
        } else {
            # monomial.
            $unmatched_monomial{$name} = 0     unless exists $unmatched_monomial{$name};
            $unmatched_monomial{$name}++;
        }

        $reasons{$reason} = 0 unless exists $reasons{$reason};
        $reasons{$reason}++;

        say STDERR "Could not match name '$name' (provider: $provider, dataset_id: $dataset_id, reason: $reason).";

    } else {
        my $taxonid = $results->[0];
        # say STDERR "Name matched successfully '$name' (taxonid $taxonid, provider: $provider, dataset_id: $dataset_id).";
        $count_matched++;

    }
}

close($csvfile);

printf "Out of $count_input_names, $count_matched names matched (%g%%), $count_not_matched names not matched (%g%%), $count_not_parsed names not parsed (%g%%).\n",
    ($count_matched/$count_input_names*100),
    ($count_not_matched/$count_input_names*100),
    ($count_not_parsed/$count_input_names*100)
;

say "Discrepancy: " . ($count_matched + $count_not_matched - $count_input_names);

use Data::Dumper;
say "Reasons: " .               Dumper(\%reasons);
say "Unmatched providers: " .   Dumper(\%unmatched_providers);
say "Unmatched dataset_id: " .  Dumper(\%unmatched_dataset_id);
say "Unmatched species: " .      Dumper(\%unmatched_genera);
say "Other unmatched names: " . Dumper(\%unmatched_monomial);

1;
