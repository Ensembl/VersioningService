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
use Config::General;
my %conf = Config::General->new($Bin.'/../conf/test.conf')->getall();


BEGIN { 
  use FindBin qw/$Bin/;
  $ENV{MONGOOSE} = "$Bin/..";
}
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;
use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Versioning::CoordinateMapper;
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
my $temp_index_folder = $mapper->create_temp_index({'species' => $species, 'dba' => $other_dba, 'analysis_name' => "refseq_import"});
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
cmp_ok($hit_count_transcripts, '==', 16, 'All 16 transcripts made it to the index');

my $dummy_content;
my $dummy_fh = IO::String->new($dummy_content);
my $rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDFCoordinateOverlap->new(handle => $dummy_fh ,config_file => "$Bin/../conf/test.conf");

# test the mapper for refseq
$mapper->calculate_overlap_score({'index_location' => $temp_index_folder , 'species' => $species, 'core_dba' => $core_dba, 'other_dba' => $other_dba,'rdf_writer' => $rdf_writer , 'source' => "refseq"});
#print Dumper($dummy_content);

like( $dummy_content, '/ENST00000296839/', 'Have got ENST00000296839' );
like( $dummy_content, '/ENST00000611664/', 'Have got ENST00000611664' );
like( $dummy_content, '/ENST00000259806/', 'Have got ENST00000259806' );
like( $dummy_content, '/ENSP00000259806/', 'Have got ENSP00000259806' );
like( $dummy_content, '/ENSP00000296839/', 'Have got ENSP00000296839' );

like( $dummy_content, '/NM_033260.3/', 'Have got NM_033260.3' );
like( $dummy_content, '/NR_106778/', 'Have got NR_106778' );
like( $dummy_content, '/NM_001452.1/', 'Have got NM_001452.1' );

like( $dummy_content, '/0.853/', 'Have got score 0.853' );
like( $dummy_content, '/0.773/', 'Have got score 0.773' );

#Try UCSC - don't pass other_dba
my $dummy_content_ucsc;
my $dummy_fh_ucsc = IO::String->new($dummy_content_ucsc);
my $rdf_writer_ucsc = Bio::EnsEMBL::Mongoose::Serializer::RDFCoordinateOverlap->new(handle => $dummy_fh_ucsc ,config_file => "$Bin/../conf/test.conf");

# test the mapper for ucsc
$mapper->calculate_overlap_score({'index_location' => $index_path , 'species' => $species, 'core_dba' => $core_dba, 'rdf_writer' => $rdf_writer_ucsc , 'source' => "ucsc"});

like( $dummy_content_ucsc, '/ENST00000296839/', 'Have got ENST00000296839' );
like( $dummy_content_ucsc, '/ENST00000611664/', 'Have got ENST00000611664' );
like( $dummy_content_ucsc, '/ENST00000259806/', 'Have got ENST00000259806' );

done_testing();
