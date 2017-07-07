use strict;
use Test::More;
#use Test::Deep;

use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use FindBin qw/$Bin/;
use IO::String;

use RDF::Trine;
use RDF::Query;


my $dummy_content;
my $dummy_fh = IO::String->new($dummy_content);
my $rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $dummy_fh ,config_file => "$Bin/../conf/test.conf");

# Test record-writing powers

my $test_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({
  id => 'uc060qbx.1',
  accessions => [qw/uc060qbx.1/],
  });

$rdf_writer->print_coordinate_overlap_xrefs("ENST00000580678",$test_record,'ucsc_transcript',"0.823");

my $store = RDF::Trine::Store::Memory->new();
my $model = RDF::Trine::Model->new($store);
my $parser = RDF::Trine::Parser->new('turtle');

$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ensembl/', $dummy_content, $model);
my $prefixes = $rdf_writer->compatible_name_spaces();

my $sparql = 'SELECT ?uri WHERE { ?uri rdfs:label "ENST00000580678"}';
my $query = RDF::Query->new($prefixes.$sparql);
# note (RDF::Query->error);
ok(! RDF::Query->error, 'No SPARQL parsing error');
my $iterator = $query->execute($model);
my @results = $iterator->get_all;

is($results[0]->{uri}->value,'http://rdf.ebi.ac.uk/resource/ensembl.transcript/ENST00000580678', 'Found Ensembl ID in overlap graph');

$sparql = 'SELECT ?uri WHERE { ?uri dc:identifier "uc060qbx.1"}';
$query = RDF::Query->new($prefixes.$sparql);
# note (RDF::Query->error);
ok(! RDF::Query->error, 'No SPARQL parsing error');
$iterator = $query->execute($model);
@results = $iterator->get_all;

is($results[0]->{uri}->value, "http://rdf.ebi.ac.uk/resource/ensembl/xref/ucsc_transcript/uc060qbx.1", 'Found UCSC ID in overlap graph');

$sparql = 'SELECT ?score WHERE {
  <http://rdf.ebi.ac.uk/resource/ensembl.transcript/ENST00000580678> term:refers-to ?xref .
  ?xref term:score ?score . 
  ?xref term:refers-to <http://rdf.ebi.ac.uk/resource/ensembl/xref/ucsc_transcript/uc060qbx.1> .
}';
$query = RDF::Query->new($prefixes.$sparql);
# note (RDF::Query->error);
ok(! RDF::Query->error, 'No SPARQL parsing error');
$iterator = $query->execute($model);
@results = $iterator->get_all;

cmp_ok($results[0]->{score}->value, '==', 0.823, 'Overlap score of 0.823 calculated and reported');


# Regression test for awkward source names with spaces in them, e.g. Project 12455
# Spaces needed to be encoded for URIs

$test_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({
  id => 'space in name',
  accessions => [qw/uc060qbx.1/],
});

my ($a,$b,$c) = $rdf_writer->generate_uris(' Vacuum', 'Spacious subject', 'pain in bum', 'Project 12455');

is($a, 'http://rdf.ebi.ac.uk/resource/ensembl/xref/Spacious%20subject/%20Vacuum', 'Source URI is whitespace-resilient');
is($b, 'http://rdf.ebi.ac.uk/resource/ensembl/xref/connection/Spacious%20subject/Project%2012455/2', 'Xref URI is whitespace-resilient');
is($c, 'http://rdf.ebi.ac.uk/resource/ensembl/xref/Project%2012455/pain%20in%20bum', 'Target URI is whitespace-resilient');


done_testing();