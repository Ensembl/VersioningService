use Modern::Perl;
use Test::More;
use Test::Exception;
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


is($converter->convert_uri_to_external_db_name('http://identifiers.org/hgnc/'), 'HGNC', 'Look up a identifiers.org namespace only');

is($converter->convert_uri_to_external_db_name('http://identifiers.org/hgnc/HGNC:1000'),'HGNC','DB name comes out, without ID');

is($converter->convert_uri_to_external_db_name('http://purl.uniprot.org/uniprot/UPI9000'),'Uniprot/SWISSPROT','LOD-based URL maps back correctly');

is($converter->convert_uri_to_external_db_name('http://rdf.ebi.ac.uk/resource/ensembl/source/Uniprot%2FSWISSPROT'),'Uniprot/SWISSPROT','Directly encoded external db name can be extracted');



is_deeply( [$converter->generate_source_uri('Uniprot/SWISSPROT','P10503')],
    ['http://rdf.ebi.ac.uk/resource/ensembl/source/Uniprot%2FSWISSPROT','http://purl.uniprot.org/uniprot/'] ,
    'Test a known ensembl_db entry that must get URI-escaped');
is_deeply([$converter->generate_source_uri('swissprot','P10503')],
  ['http://rdf.ebi.ac.uk/resource/ensembl/source/Uniprot%2FSWISSPROT','http://purl.uniprot.org/uniprot/'] ,
  'Test a known ensembl_db entry with non-specific external source');

is_deeply([$converter->generate_source_uri('refseq','NM_10')],
  ['http://rdf.ebi.ac.uk/resource/ensembl/source/RefSeq_mRNA','http://identifiers.org/refseq/'] ,
  'Test an evidenced RefSeq transcript gets binned correctly');

dies_ok(sub {$converter->generate_source_uri('refseq',undef)}, 'Ensure a RefSeq transcript without an ID creates an error');

is_deeply([$converter->generate_source_uri('RefSeq_peptide','NP_10')],
  ['http://rdf.ebi.ac.uk/resource/ensembl/source/RefSeq_peptide','http://identifiers.org/refseq/'] ,
  'Test an evidenced RefSeq protein gets binned correctly');

is_deeply([$converter->generate_source_uri('RefSeq_peptide_predicted','XP_10')],
  ['http://rdf.ebi.ac.uk/resource/ensembl/source/RefSeq_peptide_predicted','http://identifiers.org/refseq/'] ,
  'Test a predicted RefSeq protein gets binned correctly');

is_deeply([$converter->generate_source_uri('RefSeq_ncRNA','NR')],
  ['http://rdf.ebi.ac.uk/resource/ensembl/source/RefSeq_ncRNA','http://identifiers.org/refseq/'] ,
  'Test an evidenced non-coding RefSeq transcript gets binned correctly');

is_deeply([$converter->generate_source_uri('RefSeq_mRNA_predicted','XM_1000')],
  ['http://rdf.ebi.ac.uk/resource/ensembl/source/RefSeq_mRNA_predicted','http://identifiers.org/refseq/'] ,
  'Test a predicted RefSeq transcript gets binned correctly');

is_deeply([$converter->generate_source_uri('Ensembl','ENSG10')],
  ['http://rdf.ebi.ac.uk/resource/ensembl/','http://rdf.ebi.ac.uk/resource/ensembl/'],
  'Test an Ensembl Gene described in another source');

is_deeply([$converter->generate_source_uri('ensembl_transcript','ENST10')],
  ['http://rdf.ebi.ac.uk/resource/ensembl.transcript/','http://rdf.ebi.ac.uk/resource/ensembl.transcript/'],
  'Test an Ensembl Transcript described in another source');

is_deeply([$converter->generate_source_uri('ensembl_protein','ENSP10')],
  ['http://rdf.ebi.ac.uk/resource/ensembl.protein/','http://rdf.ebi.ac.uk/resource/ensembl.protein/'],
  'Test an Ensembl Translation described in another source');



done_testing;