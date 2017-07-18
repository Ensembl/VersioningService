use strict;
use warnings;

use Test::More;
use Test::Exception;
use Data::Dumper;
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;
use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use File::Path;
use Log::Log4perl;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::UCSC';

my $reader =
  Bio::EnsEMBL::Mongoose::Parser::UCSC->new(source_file => "$ENV{MONGOOSE}/t/data/ucsc/hg38.txt.gz");
isa_ok($reader, 'Bio::EnsEMBL::Mongoose::Parser::UCSC');

my $num_of_records = 0;

#create test index
my $index_path = $ENV{MONGOOSE}.'/t/data/test_index_ucsc';

if(-e $index_path) {
  rmtree $index_path;
}
  
my $indexer = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new(
  index => $index_path,
);

# read first 10 records from file
for (1 .. 10) {
  $reader->read_record();
  my $record = $reader->record;
  if ($record->has_taxon_id && ($record->has_accessions || defined $record->id)) {
    $indexer->store_record($record);
  }
  ++$num_of_records;
}
cmp_ok($num_of_records, '==', 10, 'All ten records made it to the index');

$indexer->commit;
my $interlocutor = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => { index_location => $index_path });

my $query = 'taxon_id:9606';
$interlocutor->query($query);
my @results;
while (my $hit = $interlocutor->next_result) {
  my $record = $interlocutor->convert_result_to_record($hit);
  push @results,$record;
}
cmp_ok(scalar @results, '==', 10, 'All ten records made it to the index');

# build term query
my $term_query = $interlocutor->build_term_query({field => "test_field", term => "test_field_value"});
isa_ok($term_query, 'Lucy::Search::TermQuery');

# build range query with different parameters
my $rangle_query_include_all = $interlocutor->build_range_query({field => "test_field", lower_term => "001", upper_term=>"010", include_lower => 1, include_upper => 1});
isa_ok($rangle_query_include_all, 'Lucy::Search::RangeQuery');

my $rangle_query_include_upper = $interlocutor->build_range_query({field => "test_field", upper_term=>"010",  include_upper => 1});
isa_ok($rangle_query_include_upper, 'Lucy::Search::RangeQuery');

my $rangle_query_include_lower = $interlocutor->build_range_query({field => "test_field", lower_term => "001", include_lower => 1});
isa_ok($rangle_query_include_lower, 'Lucy::Search::RangeQuery');

my($taxon_id, $chromosome, $strand, $start, $end);
$taxon_id = '9606', $chromosome = 1, $strand = -1, $start = '17369', $end = '36081';

# pad start and end
$start = sprintf("%018d", $start), $end = sprintf("%018d", $end);

my $final_results = $interlocutor->fetch_region_overlaps($taxon_id, $chromosome, $strand, $start, $end);
cmp_ok(scalar @$final_results, '==', 3, 'Got exactly 3 records as expected');

foreach my $record(@$final_results){
  ok($record->taxon_id eq "9606", "Got back right taxon_id " . $taxon_id);
  ok($record->chromosome eq "1", "Got back right chromosome " . $chromosome);
  ok($record->strand eq "-1", "Got back right strand  " . $strand);
  ok($record->transcript_start >= $start, "transcript_start ". $record->transcript_start . " is >= " . $start);
  ok($record->transcript_end <= $end, "transcript_end " . $record->transcript_end . " is <= " . $end);
}

# Test multi-index searching
# Build a second index from the ucsc data above
my $second_index_path = $ENV{MONGOOSE}.'/t/data/test_poly_index_ucsc';
if(-e $second_index_path) {
  rmtree $second_index_path;
}

my $second_indexer = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new(
  index => $second_index_path,
);
for (1..10) {
  $reader->read_record;
  $second_indexer->store_record($reader->record);
}
$second_indexer->commit;

my $poly_searcher = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => { index_location => [$index_path,$second_index_path] });
@results = ();
$poly_searcher->query($query);
while (my $hit = $poly_searcher->next_result) {
  my $record = $poly_searcher->convert_result_to_record($hit);
  push @results,$record;
}
cmp_ok(scalar @results, '==', 20, 'PolySearcher queries both indexes of 10 records (totalling 20)');

throws_ok( sub {
  $interlocutor = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => { index_location => [] });
  $interlocutor->search_engine(); # trigger lazy load
}, qr/Empty array of index paths, cannot query no indexes/, 'Empty array of index paths, cannot query no indexes');

throws_ok(sub {
  $interlocutor = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => {});
  $interlocutor->search_engine(); # trigger lazy load
}, qr/No index location provided for search engine/, 'No index location provided for search engine');

done_testing();