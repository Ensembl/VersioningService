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

is($rdf_writer->identifier('Uniprot/SPTREMBL'), 'http://purl.uniprot.org/uniprot/', 'Source name resolution');
is($rdf_writer->identifier('derp'),'http://rdf.ebi.ac.uk/resource/ensembl/xref/derp/','Unresolved identifier gives back safe answer');
is($rdf_writer->identifier('EMBL_predicted'),'http://identifiers.org/ena.embl/','Identifier without LOD entry still gets an identifiers.org prefix');

is($rdf_writer->new_xref,'http://rdf.ebi.ac.uk/resource/ensembl/xref/1','Get an xref URI');
is($rdf_writer->new_xref,'http://rdf.ebi.ac.uk/resource/ensembl/xref/2','xref id iterator increments');

# Test record-writing powers

my $test_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({
  id => 'Testy',
  accessions => [qw/a b c/],
  xref => [
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'RefSeq_dna',active => 1,version => 1, id => 'NM1'}),
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'RefSeq_dna',active => 1,version => 1, id => 'NM2'}),
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'RefSeq_dna',active => 0,version => 1, id => 'null1'})
   ],
  });

$rdf_writer->print_record($test_record,'Uniprot/SPTREMBL');

my $dependent_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({
  id => 'NM1',
  accessions => [qw/1 2 3/],
  xref => [
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'MIM_GENE', active => 1, version => 1, id => '100'}),
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'MIM_GENE', active => 1, version => 1, id => 'MrCyclic'})
  ],
});
# Spurious test data looks like uniprot_id->xref->refseq_id->xref->mim_id
$rdf_writer->print_record($dependent_record,'RefSeq_dna');

# Now try to break the implementation, by including a deliberate cycle.
my $loopy_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({
  id => 'MrCyclic',
  accessions => [qw/Pwning your SPARQL endpoint/],
  xref => [
    Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new({source => 'RefSeq_dna', active => 1, version => 1, id => 'NM1'})
  ],
});

$rdf_writer->print_record($loopy_record, 'MIM_GENE');

note $dummy_content;

# parse and validate data
my $store = RDF::Trine::Store::Memory->new();
my $model = RDF::Trine::Model->new($store);
my $parser = RDF::Trine::Parser->new('turtle');

$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ensembl/', $dummy_content, $model);

# verify data model

my $prefixes = $rdf_writer->compatible_name_spaces();
my $sparql = 'select ?hop ?source ?label where {
    <http://purl.uniprot.org/uniprot/Testy> term:refers-to+ ?hop .
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

$query = RDF::Query->new($prefixes.$sparql);
$query->error;
$iterator = $query->execute($model);
@results = $iterator->get_all;
cmp_deeply([map { $_->{id}->as_string} @results],bag(qw/"Testy" "NM1" "MrCyclic" "NM2" "100"/),'null1 not included in results, and NM1 does not appear twice');

done_testing();