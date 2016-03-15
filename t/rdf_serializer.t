use strict;
use Test::More;

use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use FindBin qw/$Bin/;

use IO::String;

my $dummy_content;
my $dummy_fh = IO::String->new($dummy_content);
my $rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(fh => $dummy_fh ,config_file => "$Bin/../conf/test.conf");


is($rdf_writer->prefix('taxon'),'http://identifiers.org/taxonomy/', 'Passthrough of RDF writing functions');

is($rdf_writer->identifier('Uniprot/SPTREMBL'), 'http://purl.uniprot.org/uniprot/', 'Source name resolution');
is($rdf_writer->identifier('derp'),undef,'Unresolved identifier gives back nothing');
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
note $dummy_content;
done_testing();