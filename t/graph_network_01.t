use strict;
use Test::More;
use Test::Deep;

use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use IO::String;
use RDF::Trine;
use RDF::Query;

my $ttl;
my $dummy_fh = IO::String->new($ttl);
my $rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $dummy_fh ,config_file => "$Bin/../conf/test.conf");

# Now test the creation of specific combinations of data, and the resulting queries over that data.

sub xrefs {
  my $list_ref = shift;
  my @proper_xrefs;
  foreach my $xref (@$list_ref) {
    push @proper_xrefs, Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new($xref);
  }
  return \@proper_xrefs;
}

my @records;
# e = ensembl
# u = uniprot
# r = refseq
# etc.
# Test data is entirely synthetic, any resemblance to personages living or dead is purely coincidental

push @records, ['Uniprot/SWISSPROT', Bio::EnsEMBL::Mongoose::Persistence::Record->new({ 
  id => 'u1',
  accessions => [qw/u1 protein1/],
  xref => xrefs([
    {source => 'RefSeq_dna',active => 1,id => 'rt1'}, # Link from protein to transcript
    {source => 'RefSeq_peptide',active => 1,id => 'rp2'}, # Link from protein to protein
    {source => 'ensembl',active => 1,id => 'eg1'}, # Link from protein to Ensembl gene 
    {source => 'ensembl_protein',active => 1,id => 'ep2'}, # Link from protein to Ensembl protein
    {source => 'CAZy', active => 1, id => 'GT10'}
  ])
})
];

push @records,['RefSeq_peptide', Bio::EnsEMBL::Mongoose::Persistence::Record->new({ 
  id => 'rp2',
  accessions => [qw/rp2/],
  xref => xrefs([
    {source => 'ensembl_protein',active => 1,id => 'ep2'}, # Link from protein to Ensembl protein 
    {source => 'PDB', active => 1, id => 'pdb1'}, # link from protein to annotation
  ])
})
];

push @records,['HGNC', Bio::EnsEMBL::Mongoose::Persistence::Record->new({ 
  id => 'hgnc1',
  accessions => [qw/hgnc:1/],
  xref => xrefs([
    {source => 'EntrezGene',active => 1,id => 'ncbi1'}, # Link from gene to gene 
    {source => 'lrg',active => 1,id => 'lrg1'}, # gene to gene
    {source => 'RefSeq_dna',active => 1, id => 'rt1'} # gene to transcript
  ])
})
];

push @records,['EntrezGene', Bio::EnsEMBL::Mongoose::Persistence::Record->new({ 
  id => 'ncbi1',
  accessions => [qw/nbci1 entrez1/],
  xref => xrefs([
    {source => 'ensembl',active => 1,id => 'eg1'}, # gene to gene 
    {source => 'hgnc',active => 1,id => 'hgnc1'}, # gene to gene
  ])
})
];

push @records,['CAZy', Bio::EnsEMBL::Mongoose::Persistence::Record->new({ 
  id => 'GT10',
  accessions => [qw/annotation_link/],
  xref => xrefs([
    {source => 'interpro',active => 1,id => 'ip1'}, # annotation to annotation
    {source => 'ensembl', active => 1,id => 'eg2'} # annotation to gene
  ])
})
];

push @records,['lrg', Bio::EnsEMBL::Mongoose::Persistence::Record->new({ 
  id => 'lrg1',
  accessions => [qw/annotation_link/],
  xref => xrefs([
    {source => 'ensembl', active => 1,id => 'eg2'} # annotation to gene
  ])
})
];


# Dump the lot to RDF in bidirectional form
foreach my $write_me (@records) {
  my ($source,$record) = @$write_me;
  $rdf_writer->print_slimline_record($record,$source);  
}

# TODO: Add alignment links, overlap links and so on.

my $store = RDF::Trine::Store::Memory->new();
my $model = RDF::Trine::Model->new($store);
my $parser = RDF::Trine::Parser->new('turtle');

note $ttl;
$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ensembl/', $ttl, $model);
ok($model);

sub query {
  my ($query,$var_name,$expected_accessions,$test_name) = @_;
  my $prefixes = $rdf_writer->compatible_name_spaces();
  $query = RDF::Query->new($prefixes.$query);
  $query->error;
  my $iterator = $query->execute($model);
  my @results = $iterator->get_all;
  cmp_deeply([map {$_->{$var_name}->value} @results],bag(@$expected_accessions),$test_name);
}

my $query = 'select ?uri from <http://rdf.ebi.ac.uk/resource/ensembl/> where { 
  <http://purl.uniprot.org/uniprot/u1> term:refers-to ?uri .
  VALUES ?uri { <http://identifiers.org/refseq/rp2> }
}';
query($query,'uri',['http://identifiers.org/refseq/rp2'],'Direct xref, one hop');


$query = 'select ?uri from <http://rdf.ebi.ac.uk/resource/ensembl/> where { 
  <http://identifiers.org/ncbigene/ncbi1> <http://rdf.ebi.ac.uk/terms/ensembl/refers-to>+ ?uri .
  FILTER (?uri != <http://identifiers.org/ncbigene/ncbi1>)
}';

query($query,'uri',[
  'http://identifiers.org/hgnc/hgnc1',
  'http://identifiers.org/lrg/lrg1',
  'http://rdf.ebi.ac.uk/resource/ensembl/eg1',
  'http://rdf.ebi.ac.uk/resource/ensembl/eg2'
  ],
  'Multi-hop transitive gene xrefs');



$query = 'select ?uri from <http://rdf.ebi.ac.uk/resource/ensembl/> where { 
  <http://rdf.ebi.ac.uk/resource/ensembl.protein/ep2> <http://rdf.ebi.ac.uk/terms/ensembl/refers-to>+ ?uri .
  FILTER (?uri != <http://rdf.ebi.ac.uk/resource/ensembl.protein/ep2>)
}';

query($query,'uri',[
  'http://purl.uniprot.org/uniprot/u1',
  'http://identifiers.org/refseq/rp2'
  ],
  'Multi-hop transitive proteins');




done_testing;