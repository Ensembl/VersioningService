use Modern::Perl;
use Test::More;
use FindBin qw/$Bin/;
use Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings;
use Config::General;

my %conf = Config::General->new($Bin.'/../conf/test.conf')->getall();

my $converter = Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings->new($conf{LOD_location},$Bin.'/../conf/xref_LOD_schema.json');
ok ($converter);
is ($converter->identifier_org_translation('RefSeq_ncRNA'), 'http://identifiers.org/refseq/', "Test simple mapping 1");
is ($converter->identifier_org_translation('HGNC'), 'http://identifiers.org/hgnc/', "Test simple mapping 2");
is ($converter->identifier_org_translation('RefSeq_ncRNA_predicted'), 'http://identifiers.org/refseq/', "Test simple mapping 3");
is ($converter->identifier_org_translation('Nonsense'), undef, 'Source not known by identifiers.org comes back undef');

is($converter->identifier('HGNC'), 'http://identifiers.org/hgnc/', 'identifiers.org URL correctly generated');
is($converter->identifier('Nonsense'), 'http://rdf.ebi.ac.uk/resource/ensembl/xref/Nonsense/', 'New/unseen sources get localised in an Ensembl bucket');

my $mapping = $converter->get_mapping('UniProt/SWISSPROT');
is($mapping->{canonical_LOD},"http://purl.uniprot.org/uniprot/","Test full mapping fetch");

is($converter->LOD_uri('UniProt/SWISSPROT'),"http://purl.uniprot.org/uniprot/","Check LOD_uri() functions");
is($converter->LOD_uri('durpadurp'),undef,'Check results of a missing LOD mapping');

cmp_ok($converter->allowed_xrefs('UniProt/SWISSPROT','RefSeq_peptide'), '==', 1, 'Same classes of data can link in both directions');
cmp_ok($converter->allowed_xrefs('Ensembl','eggNOG'), '==', 0 ,'Annotation type sources cannot be linked transitively to other feature types');
cmp_ok($converter->allowed_xrefs('RefSeq_ncRNA','ensembl'),'==',0,'Features of different types may not xref to each other');
cmp_ok($converter->allowed_xrefs('ensembl_transcript','DrStrangelove'),'==',0,'Unfamiliar sources do not get links');
cmp_ok($converter->allowed_xrefs('DrStrangelove','ensembl_transcript'),'==',0,'Unfamiliar sources do not create links');
done_testing;