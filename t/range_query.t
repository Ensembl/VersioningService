# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use lib 'buildlib';
use Test::More;
use Test::Differences;

use List::Util qw( shuffle );
use Data::Dumper;

use base qw( Lucy::Plan::Schema );
use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;


sub new {
    my $self = shift->SUPER::new(@_);
    return $self;
}

package main;
my $target_folder  = '/Users/prem/workspace/software/VersioningService/tmp/tmp_download/UCSC/UCSC/20170206/index';
#my $target_folder  = '/Users/prem/workspace/software/VersioningService/tmp/tmp_download/UCSC/UCSC/20170206/index_updated_full'; (working)
#my $target_folder  = '/Users/prem/workspace/software/VersioningService/t/../t/data/test_index_ucsc';
my $searcher = Lucy::Search::IndexSearcher->new( index => $target_folder );
my $match_all_query = Lucy::Search::MatchAllQuery->new;

#get total count of documents
my $hits = $searcher->hits(
        query      => $match_all_query,
        num_wanted => 100000000000000000,
    );

my $hit_count = $hits->total_hits;  # get the hit count here
print "======Total doc Count from source =======: $hit_count\n";
ok($hit_count == 261541, "Got the right hit count");

my $hit = $hits->next;
print Dumper($hit);
print length($hit->{'transcript_start'}), "\n";
print "Hit  ", $hit->{'id'}, ' ', $hit->{'chromosome'}, ' ', $hit->{'strand'}, ' ', $hit->{'taxon_id'}, ' ', $hit->{'transcript_start'}, ' ', $hit->{'transcript_end'}, "\n";
ok(length($hit->{'transcript_start'}) == 18, "Got transcript_start with padding");

my $transcript_start = "000000000000010000";
my $transcript_end =   "000000000000090500";
my $taxon_id = "9606";
my $chromosome = "1";
my $strand = "1";

#my $transcript_start = "000000000000017369";
#my $transcript_end =   "000000000000036081";
#my $taxon_id = "9606";
#my $chromosome = "1";
#my $strand = "-1";

print "Input : transcript_start => $transcript_start\t  transcript_end => $transcript_end \t taxon_id => $taxon_id  \t chromosome => $chromosome \t strand = $strand\n";



=head1
    Original SQL Query
    SELECT    coord_xref_id, accession,
              txStart, txEnd,
              cdsStart, cdsEnd,
              exonStarts, exonEnds
    FROM      coordinate_xref
    WHERE     species_id = ?
    AND       chromosome = ? AND strand   = ?
    AND       ((txStart BETWEEN ? AND ?)        -- txStart in region
    OR         (txEnd   BETWEEN ? AND ?)        -- txEnd in region
    OR         (txStart <= ? AND txEnd >= ?))   -- region is fully contained
    ORDER BY  accession
    
    SELECT coord_xref_id, accession, txStart, txEnd, cdsStart, cdsEnd, exonStarts, exonEnds FROM coordinate_xref
    WHERE species_id =9606 AND chromosome = 1 AND strand  = -1  AND ((txStart BETWEEN 10000 AND 90500) OR (txEnd BETWEEN 10000 AND 90500) OR (txStart <= 10000 AND txEnd >= 90500))
    ORDER BY  accession;

=cut

my $term_query_species = Lucy::Search::TermQuery->new(
    field => 'taxon_id',
    term  => $taxon_id, 
);

#get total count of documents
my $hits_species = $searcher->hits(
        query      => $term_query_species,
        num_wanted => 100000000000000000,
    );

my $hit_count_species = $hits_species->total_hits;  # get the hit count here
print "======Total doc Count from species =======: $hit_count_species\n";
ok($hit_count_species == 197782, "Got the right hit count for species $taxon_id");

#============


my $term_query_chromosome = Lucy::Search::TermQuery->new(
    field => 'chromosome',
    term  => $chromosome, 
);


my $term_query_strand = Lucy::Search::TermQuery->new(
    field => 'strand',
    term  => $strand, 
);

my $taxon_and_chr_strand_query = Lucy::Search::ANDQuery->new(
    children => [ $term_query_species, $term_query_chromosome, $term_query_strand ],
);

my $hits_taxon_and_chr_strand = $searcher->hits(
        query      => $taxon_and_chr_strand_query,
        num_wanted => 100000000000000000,
    );

my $hits_taxon_and_chr_strand_count = $hits_taxon_and_chr_strand->total_hits;  # get the hit count here
print "======Total doc Count from taxon and chr and strand query =======: $hits_taxon_and_chr_strand_count\n";


my $range_query1 = Lucy::Search::RangeQuery->new(
    field         => 'transcript_start', 
    lower_term    => $transcript_start,
    upper_term    => $transcript_end,
    include_upper => 1,
    include_lower => 1,
);




my $range_query2 = Lucy::Search::RangeQuery->new(
    field         => 'transcript_end', 
    lower_term    => $transcript_start,
    upper_term    => $transcript_end,
    include_upper => 1,
    include_lower => 1,
);

#lower_term - Lower delimiter. If not supplied, all values less than upper_term will pass.
my $range_query3 = Lucy::Search::RangeQuery->new(
    field         => 'transcript_start', 
    upper_term    => $transcript_start,
    include_upper => 1,
);

#upper_term - Upper delimiter. If not supplied, all values greater than lower_term will pass.
my $range_query4 = Lucy::Search::RangeQuery->new(
    field         => 'transcript_end', 
    lower_term    => $transcript_end,
    include_lower => 1,
);

#(txStart <= 10000 AND txEnd >= 90500))
my $and_query_range = Lucy::Search::ANDQuery->new(
    children => [ $range_query3, $range_query4 ],
);

#== ((txStart BETWEEN 10000 AND 90500) OR (txEnd BETWEEN 10000 AND 90500) OR (txStart <= 10000 AND txEnd >= 90500))
my $or_query = Lucy::Search::ORQuery->new(
    children => [ $range_query1, $range_query2, $and_query_range ],
);

my $final_query = Lucy::Search::ANDQuery->new(
    children => [ $taxon_and_chr_strand_query, $or_query ],
);


$hits = $searcher->hits(
        query      => $final_query,
        num_wanted => 1000000,
    );

$hit_count = $hits->total_hits;  # get the hit count here
print "======HIT Count Final =======: $hit_count\n";
my @results;
while ( my $hit = $hits->next ) {
  push @results, $hit;
}
print Dumper(@results);

foreach my $hit(@results){
	print_hit($hit);
}

sub print_hit{
  my $hit = shift;
  print "Hit  ", $hit->get_doc_id(), ' ', $hit->{'id'}, ' ', $hit->{'chromosome'}, ' ', $hit->{'strand'}, ' ', $hit->{'taxon_id'}, ' ', 
  $hit->{'transcript_start'}, ' ', $hit->{'transcript_end'},' ', 
  $hit->{'transcript_start_padded'}, ' ', $hit->{'transcript_end_padded'},' ', 
  $hit->{'cds_start'}, ' ', $hit->{'cds_end'}, ' ',
  $hit->{'exon_starts'}, ' ',$hit->{'exon_ends'}, "\n";
}



done_testing();
