use Modern::Perl;
use Test::More;
use FindBin qw/$Bin/;
use Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings;
use Config::General;

my %conf = Config::General->new($Bin.'/../conf/test.conf')->getall();

my $converter = Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings->new($conf{LOD_location});
ok ($converter);
is ($converter->identifier_org_translation('RefSeq_ncRNA'), 'http://identifiers.org/refseq/', "Test simple mapping 1");
is ($converter->identifier_org_translation('HGNC'), 'http://identifiers.org/hgnc/', "Test simple mapping 2");
is ($converter->identifier_org_translation('RefSeq_ncRNA_predicted'), 'http://identifiers.org/refseq/', "Test simple mapping 3");

my $mapping = $converter->get_mapping('Uniprot/SWISSPROT');
is($mapping->{canonical_LOD},"http://purl.uniprot.org/uniprot/","Test full mapping fetch");

is($converter->LOD_uri('Uniprot/SWISSPROT'),"http://purl.uniprot.org/uniprot/","Check LOD_uri() functions");
is($converter->LOD_uri('durpadurp'),undef,'Check results of a missing LOD mapping');

done_testing;