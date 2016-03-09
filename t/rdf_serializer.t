use strict;
use Test::More;

use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use FindBin qw/$Bin/;

my $dummy_fh;
my $rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(fh => \$dummy_fh ,config_file => "$Bin/../conf/test.conf");


is($rdf_writer->prefix('taxon'),'http://identifiers.org/taxonomy/', 'Passthrough of RDF writing functions');

is($rdf_writer->identifier('Uniprot/SPTREMBL'), 'http://purl.uniprot.org/uniprot/', 'Source name resolution');
is($rdf_writer->identifier('derp'),undef,'Unresolved identifier gives back nothing');
is($rdf_writer->identifier('EMBL_predicted'),'http://identifiers.org/ena.embl/','Identifier without LOD entry still gets an identifiers.org prefix');

done_testing();