use strict;
use Test::More;
use Test::Deep;

use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use FindBin qw/$Bin/;

use IO::String;
use RDF::Trine;
use RDF::Query;

my $dummy_content;
my $dummy_fh = IO::String->new($dummy_content);
my $rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $dummy_fh ,config_file => "$Bin/../conf/test.conf");


is($rdf_writer->prefix('taxon'),'http://identifiers.org/taxonomy/', 'Passthrough of RDF writing functions');
is($rdf_writer->prefix('dcterms'),'http://purl.org/dc/terms/', 'ditto');

is($rdf_writer->identifier('UniProt/SPTREMBL'), 'http://purl.uniprot.org/uniprot/', 'Source name resolution');
is($rdf_writer->identifier('derp'),'http://rdf.ebi.ac.uk/resource/ensembl/xref/derp/','Unresolved identifier gives back safe answer');
is($rdf_writer->identifier('EMBL_predicted'),'http://identifiers.org/ena.embl/','Identifier without LOD entry still gets an identifiers.org prefix');

is($rdf_writer->new_xref('test','target'),'http://rdf.ebi.ac.uk/resource/ensembl/xref/connection/test/target/1','Get an xref URI');
is($rdf_writer->new_xref('test','target'),'http://rdf.ebi.ac.uk/resource/ensembl/xref/connection/test/target/2','xref id iterator increments');

# Test record-writing powers with synthetic data

my $test_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({
  id => 'Testy',
  accessions => [qw/a b c/],
  xref => [
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'RefSeq_dna',active => 1,version => 1, id => 'NM1'}),
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'RefSeq_dna',active => 1,version => 1, id => 'NM2'}),
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'RefSeq_dna',active => 0,version => 1, id => 'null1'})
   ],
  });


my $dependent_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({
  id => 'NM1',
  accessions => [qw/1 2 3/],
  xref => [
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'flybase_transcript_id', active => 1, version => 1, id => '100'}),
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'flybase_transcript_id', active => 1, version => 1, id => 'MrCyclic'})
  ],
});
# Spurious test data looks like uniprot_id->xref->refseq_id->xref->mim_id
# Now try to break the implementation, by including a deliberate cycle.
my $loopy_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({
  id => 'MrCyclic',
  accessions => [qw/Pwning your SPARQL endpoint/],
  xref => [
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'RefSeq_dna', active => 1, version => 1, id => 'NM1'})
  ],
  comment => 'Lengthy description for humans'
});

$rdf_writer->print_record($test_record,'ensembl_transcript');
$rdf_writer->print_record($dependent_record,'RefSeq_dna');
$rdf_writer->print_record($loopy_record, 'flybase_transcript_id');

# Add some unrelated links to test Checksum link generation
# Checksum records are found by their checksum so they don't need to look very interesting
my $checksum_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({
  id => 'MrHex'
});
$rdf_writer->print_checksum_xrefs('ENST1',$checksum_record,'RNACentral');


note $dummy_content;
# parse and validate data
my $store = RDF::Trine::Store::Memory->new();
my $model = RDF::Trine::Model->new($store);
my $parser = RDF::Trine::Parser->new('turtle');

$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ensembl/', $dummy_content, $model);

# verify data model

my $prefixes = $rdf_writer->compatible_name_spaces();
my $sparql = 'select ?hop ?source ?label where {
    <http://rdf.ebi.ac.uk/resource/ensembl.transcript/Testy> term:refers-to+ ?hop .
    ?hop dcterms:source ?source .
    OPTIONAL { ?hop rdfs:label ?label . }
  }';

my $query = RDF::Query->new($prefixes.$sparql);
$query->error;
my $iterator = $query->execute($model);
my @results = $iterator->get_all;
note join "\n",@results;
cmp_ok(scalar @results, '==', 4,'Explore all linked xrefs, cyclic one does not end world');
cmp_deeply(['','',qw/"1" "Pwning"/],bag(map { if (defined $_->{label}) {$_->{label}->as_string} } @results), 'Check all xref primary labels');

$sparql = 'select ?id where {
    ?node dc:identifier ?id .
  }';

# Check on checksum-typed xrefs
$query = RDF::Query->new($prefixes.$sparql);
$query->error;
$iterator = $query->execute($model);
@results = $iterator->get_all;
cmp_deeply([map { $_->{id}->as_string} @results],bag(qw/"Testy" "NM1" "MrCyclic" "NM2" "100" "MrHex" "ENST1"/),'null1 not included in results, and NM1 does not appear twice');

$sparql = 'select ?id ?target_id where {
    ?node term:refers-to ?hop .
    ?node dc:identifier ?id .
    ?hop rdf:type term:Checksum .
    ?hop term:refers-to ?xref .
    ?xref dc:identifier ?target_id.
  }';

$query = RDF::Query->new($prefixes.$sparql);
$query->error;
$iterator = $query->execute($model);
my $result = $iterator->next;

cmp_deeply([qw/ "ENST1" "MrHex"/], [$result->{id}->as_string,$result->{target_id}->as_string] , 'Checksum-type xref successfully extracted');

$sparql = 'select ?comment where {
    ?node dc:identifier "MrCyclic" .
    ?node rdfs:comment ?comment.
  }';

$query = RDF::Query->new($prefixes.$sparql);
$query->error;
$iterator = $query->execute($model);
$result = $iterator->next;

is($result->{comment}->as_string,'"Lengthy description for humans"','Comments correctly expressed in RDF');

done_testing();