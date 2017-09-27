=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

use strict;
use warnings;

use Test::More;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Test::MultiTestDB;
use File::Path;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;
use Config::General;
my %conf = Config::General->new($Bin.'/../conf/test.conf')->getall();

use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;
use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Versioning::CoordinateMapper;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Bio::EnsEMBL::Mongoose::Taxonomizer;
use Bio::EnsEMBL::Versioning::TestDB qw/broker get_conf_location/;

my $surplus_db = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens' );
my $core_dba = $surplus_db->get_DBAdaptor('core');
my $other_dba = $surplus_db->get_DBAdaptor('otherfeatures');


my $broker = broker();
my $mapper = Bio::EnsEMBL::Versioning::CoordinateMapper->new;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::UCSC';

my $reader =
  Bio::EnsEMBL::Mongoose::Parser::UCSC->new(source_file => "$ENV{MONGOOSE}/t/data/ucsc/hg38.chr6.txt.gz");
isa_ok($reader, 'Bio::EnsEMBL::Mongoose::Parser::UCSC');

my $num_of_records = 0;

my $species = 'homo_sapiens';

#create test index
my $index_path = $ENV{MONGOOSE}.'/t/data/test_index_ucsc';
if(-e $index_path) {
  rmtree $index_path;
}
my $indexer = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new(
  index => $index_path,
);

# read only records from chromosome 6 and store it in the test_index_ucsc
  while($reader->read_record()){
    my $record = $reader->record;
    next unless $record->chromosome eq '6';
    if ($record->has_taxon_id && ($record->has_accessions || defined $record->id)) {
      $indexer->store_record($record);
      ++$num_of_records;
    }
}
$indexer->commit;
cmp_ok($num_of_records, '==', 7705, 'All 7705 records made it to the index');

# query using LucyQuery with taxon_id filter and check if you have all the records
my $interlocutor = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => { index_location => $index_path });
my $query = "taxon_id:9606";
$interlocutor->query($query);
my @results;
while (my $hit = $interlocutor->next_result) {
  my $record = $interlocutor->convert_result_to_record($hit);
  push @results,$record;
}
cmp_ok(scalar @results, '==', 7705, 'All 7705 records made it to the index');

# store features from otherfeatures database into lucy index and check if you have got the records back
my $temp_index_folder = $mapper->create_index_from_database(species => $species, dba => $other_dba, analysis_name => "refseq_import");
my $searcher = Lucy::Search::IndexSearcher->new( index => $temp_index_folder );
my $lucy =  Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new( index => $temp_index_folder );

my $term_query_species = Lucy::Search::TermQuery->new(
    field => 'taxon_id',
    term  => '9606', 
);

#get total count of documents
my $hits_species = $searcher->hits(
        query      => $term_query_species,
        num_wanted => 100000000000000000,
    );

my $hit_count_transcripts = $hits_species->total_hits;  # get the hit count here
cmp_ok($hit_count_transcripts, '==', 15, 'All transcripts (15) made it to the index, one with a non-RefSeq name was excluded');

my $dummy_content;
my $dummy_fh = IO::String->new($dummy_content);
my $rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $dummy_fh ,config_file => "$Bin/../conf/test.conf");

# test the mapper for refseq
$mapper->calculate_overlap_score(index_location => [$temp_index_folder] , species => $species, core_dba => $core_dba, other_dba => $other_dba,rdf_writer => $rdf_writer , source => "refseq");
#print Dumper($dummy_content);

use RDF::Trine;
use RDF::Query;

my $store = RDF::Trine::Store::Memory->new();
my $model = RDF::Trine::Model->new($store);
my $parser = RDF::Trine::Parser->new('turtle');
$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ensembl/', $dummy_content, $model);
my $prefixes = $rdf_writer->compatible_name_spaces();
my $sparql = 'select ?stable_id ?score ?entity from <http://rdf.ebi.ac.uk/resource/ensembl/> where { 
  ?ensembl_feature term:refers-to ?xref .
  ?ensembl_feature rdfs:label ?stable_id .
  ?xref term:score ?score .
  ?xref term:refers-to ?entity .
  }';
my $sparql_query = RDF::Query->new($prefixes.$sparql);
$sparql_query->error;
my @sparql_results = $sparql_query->execute($model)->get_all;

my %expected_scores = (ENST00000296839 => 0.87, ENSP00000296839 => 0.87, ENST00000259806 => 1, ENSP00000259806 => 1, ENST00000611664 => 1);

foreach my $result (@sparql_results) {
  my $score;
  my $feature_id = $result->{stable_id}->value;
  if (exists $expected_scores{$feature_id}) {
    cmp_ok(sprintf("%.3f", $result->{score}->value), '==', $expected_scores{$feature_id}, "Testing for score against $feature_id");
  } else {
    fail("SPARQL query returned unexpected value $feature_id");
  }
}

# #Try UCSC - don't pass other_dba
 my $dummy_content_ucsc;
 my $dummy_fh_ucsc = IO::String->new($dummy_content_ucsc);
 my $rdf_writer_ucsc = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $dummy_fh_ucsc ,config_file => "$Bin/../conf/test.conf");

# # test the mapper for ucsc
# Rest triplestore to prevent contamination from previous testing
$store = RDF::Trine::Store::Memory->new();
$mapper->calculate_overlap_score(index_location => [$index_path] , species => $species, core_dba => $core_dba, rdf_writer => $rdf_writer_ucsc , source => "ucsc");
$model = RDF::Trine::Model->new($store);
$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ucsc/', $dummy_content_ucsc, $model);

$sparql = 'select ?stable_id ?ucsc_id from <http://rdf.ebi.ac.uk/resource/ucsc/> where { 
  ?ensembl_feature rdfs:label ?stable_id .
  ?ensembl_feature term:refers-to ?xref .
  ?xref term:refers-to ?uri .
  ?uri dc:identifier ?ucsc_id .
  }';
$sparql_query = RDF::Query->new($prefixes.$sparql);
$sparql_query->error;
@sparql_results = $sparql_query->execute($model)->get_all;

my %expected_ids = (ENST00000603854 => 'uc063ljp.1', 
                    ENST00000314040 => 'uc003mtk.1', 
                    ENST00000296839 => 'uc003mtl.5', 
                    ENST00000627866 => 'uc063ljq.1',
                    ENST00000568244 => 'uc063ljr.1',
                    ENST00000259806 => 'uc003mtm.3',
                    ENST00000611664 => 'uc032wiw.1',
                    ENST00000415106 => 'uc063ozn.1');

foreach my $result (@sparql_results) {
  my $id = $result->{stable_id}->value;
  if (exists $expected_ids{$id}) {
    is($result->{ucsc_id}->value, $expected_ids{$id}, "Ensembl Transcript $id expected and found linked to UCSC ID");
  } else {
    fail("Missing results for $id in SPARQL results");
  }
}

# Test get_best_score_id
#If there is a stalemate, choose the one with the best translateable exon overlap score
my %transcript_result = ("NM1" => 0.98, "NM2" => 0.98);
my %tl_transcript_result = ("NM2" => 1);

#We should expect NM2
my ($best_score, $best_id)  = $mapper->get_best_score_id(\%transcript_result, \%tl_transcript_result);
cmp_ok($best_score, "==", 0.98, "Got the right score");
cmp_ok($best_id, "eq", 'NM2', "Got the right id");

#Test compute assignments
use Data::Dumper;
my %all_transcript_result;
$all_transcript_result{"R1"}{"E1"} = 0.99;

$all_transcript_result{"R2"}{"E1"} = 0.98;
$all_transcript_result{"R2"}{"E2"} = 0.99;

$all_transcript_result{"R3"}{"E3"} = 1;

$all_transcript_result{"R4"}{"E2"} = 0.58;
$all_transcript_result{"R4"}{"E3"} = 0.78;
$all_transcript_result{"R4"}{"E4"} = 0.78;
$all_transcript_result{"R4"}{"E5"} = 0.78;

my %all_tl_transcript_result;
$all_tl_transcript_result{"R4"}{"E4"} = 1;

#expected assignments "R1" => "E1", "R2" => "E2" , "R3" => "E3", "R4" => "E4"
my ($all_transcript_result_computed, $all_tl_transcript_result_computed) =  $mapper->compute_assignments(\%all_transcript_result, \%all_tl_transcript_result);
print Dumper ($all_transcript_result_computed);
ok($all_transcript_result_computed->{"R1"}->{"E1"} == 0.99 );
ok($all_transcript_result_computed->{"R2"}->{"E2"} == 0.99 );
ok($all_transcript_result_computed->{"R3"}->{"E3"} == 1 );
ok($all_transcript_result_computed->{"R4"}->{"E4"} == 0.78 );

# Post-test cleanup
if(-e $index_path) {
  rmtree $index_path;
}

done_testing();
