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
use RDF::Trine::Node::Resource;
use RDF::Query;

my $ttl;
my $dummy_fh = IO::String->new($ttl);
my $rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $dummy_fh ,config_file => "$Bin/../conf/test.conf");

my $full_fat_ttl;
my $big_dummy_fh = IO::String->new($full_fat_ttl);
my $other_rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $big_dummy_fh ,config_file => "$Bin/../conf/test.conf");

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
  $other_rdf_writer->print_record($record,$source);
}
$rdf_writer->print_source_meta;
$other_rdf_writer->print_source_meta;
# TODO: Add alignment links, overlap links and so on.

my $store = RDF::Trine::Store::Memory->new();
my $model = RDF::Trine::Model->new($store);
my $parser = RDF::Trine::Parser->new('turtle');
my $chunky_store = RDF::Trine::Store::Memory->new();
my $chunky_model = RDF::Trine::Model->new($chunky_store);
# note $ttl;
$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ensembl/', $ttl, $model);
$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ensembl_full/', $full_fat_ttl, $chunky_model);
ok($model);

sub query {
  my ($query,$var_name,$expected_accessions,$test_name,$specific_model) = @_;
  $specific_model = $model unless $specific_model;
  my $prefixes = $rdf_writer->compatible_name_spaces();
  $query = RDF::Query->new($prefixes.$query);
  note (RDF::Query->error) unless $query;
  my $iterator = $query->execute($specific_model);
  my @results = $iterator->get_all;
  cmp_deeply([map {$_->{$var_name}->value} @results],bag(@$expected_accessions),$test_name);
}

sub ordered_query {
  my ($query,$var_name,$expected_accessions,$test_name) = @_;
  my $prefixes = $rdf_writer->compatible_name_spaces();
  $query = RDF::Query->new($prefixes.$query);
  note (RDF::Query->error) unless $query;
  my $iterator = $query->execute($model);
  my @results = $iterator->get_all;
  cmp_deeply([map {$_->{$var_name}->value} @results],$expected_accessions, $test_name);
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

# Now check the fully-fledged model
# note $full_fat_ttl;

$query = 'select distinct ?id from <http://rdf.ebi.ac.uk/resource/ensembl_full/> where {
  ?uri term:refers-to ?xref .
  ?xref rdf:type term:Direct ;
        term:refers-to ?other_uri .
  ?other_uri dc:identifier ?id .
  }';

query($query,'id',[qw/GT10 eg1 eg2 ep2 hgnc1 ip1 lrg1 ncbi1 pdb1 rp2 rt1/],'Direct xrefs return all annotations as well as features',$chunky_model);

# Test that hgnc ID wins

$query = 'select ?id ?priority from <http://rdf.ebi.ac.uk/resource/ensembl/> where {
  <http://rdf.ebi.ac.uk/resource/ensembl/eg2> term:refers-to+ ?xref_uri .
  ?xref_uri dcterms:source ?source ;
            dc:identifier ?id .
  ?source term:priority ?priority .
} ORDER BY DESC(?priority)';
# Note, ORDER BY DESC puts things with no ?priority top unless you explicitly require a value in the query

ordered_query($query,'id',[qw/hgnc1 ncbi1/], 'Correctly select IDs in priority order');


$query = 'select ?id ?priority from <http://rdf.ebi.ac.uk/resource/ensembl/> where {
  <http://identifiers.org/ncbigene/ncbi1> term:refers-to+ ?xref_uri .
  ?xref_uri dcterms:source ?source ;
            dc:identifier ?id .
  ?source term:priority ?priority .
} ORDER BY DESC(?priority)';

ordered_query($query,'id',[qw/hgnc1 ncbi1/], "Doesn't matter where you start, still get the same ID");


# Now suppose that eg1 has been retired from Ensembl, so we are duty bound to remove any trace of links to it.
# Delete from non-transitive graph first, HOWEVER RDF::Trine::Model does not support deletes in its regular interface. So none of this works...

$query = 'SELECT ?xref FROM <http://rdf.ebi.ac.uk/resource/ensembl_full/> WHERE {
  ?uri term:refers-to ?xref . ?xref term:refers-to ensembl:eg1 .
  }';
my $prefixes = $rdf_writer->compatible_name_spaces();
my $rdf_query = RDF::Query->new($prefixes.$query);
my $iterator = $rdf_query->execute($chunky_model);
note 'Model size prior to removing triples: '.$chunky_model->size;
while (my $hit = $iterator->next) {
  my $xref = $hit->{xref}->value;
  note "Delete $xref";
  # $query = sprintf 'WITH <http://rdf.ebi.ac.uk/resource/ensembl/> DELETE { %s term:refers-to ?any }',$xref;
  # my $delete_query = RDF::Query->new($prefixes.$query);
  # note (RDF::Query->error) unless $delete_query;
  # $delete_query->execute($model);
  # $query = sprintf 'WITH <http://rdf.ebi.ac.uk/resource/ensembl/> DELETE { ?any term:refers-to %s }',$xref;
  # $delete_query = RDF::Query->new($prefixes.$query);
  # $delete_query->execute($model);
  # # Further cleanup would require checking to see whether entity labels were still required based on whether they are connected to anything
  # e.g. DELETE { ?any dc:identifier ?label } WHERE { ?any dc:identifier ?label . FILTER NOT EXISTS {{ ?any_other term:refers-to ?any. } UNION { ?any term:refers-to ?anything . }}

  # RDF::Trine::Model direct delete. Not transferrable to a real server
  # my $predicate = RDF::Trine::Node::Resource->new('http://rdf.ebi.ac.uk/terms/ensembl/refers-to');
  my $xref_node = RDF::Trine::Node::Resource->new($xref);
  $chunky_model->remove_statements(undef,     undef,$xref_node);
  $chunky_model->remove_statements($xref_node,undef,undef);

  my $resource_node = RDF::Trine::Node::Resource->new('http://rdf.ebi.ac.uk/resource/ensembl/eg1');
  $model->remove_statements(undef,undef,$resource_node);
  $model->remove_statements($resource_node,undef,undef);
}
note 'Model size after deleting statements linked to eg1: '.$chunky_model->size;
# Now test to see that eg1 is gone.
note $full_fat_ttl;
$query = 'select ?uri ?label from <http://rdf.ebi.ac.uk/resource/ensembl_full/> where { 
  <http://identifiers.org/ncbigene/ncbi1> <http://rdf.ebi.ac.uk/terms/ensembl/refers-to>+ ?uri .
  ?uri rdfs:label ?label .
  FILTER (?uri != <http://identifiers.org/ncbigene/ncbi1>)
}';

query($query,'uri',[
  'http://identifiers.org/hgnc/hgnc1',
  'http://identifiers.org/lrg/lrg1'
  ],
  'Multi-hop transitive gene xrefs minus the deleted miscreant in full graph',
  $chunky_model);
# 'http://rdf.ebi.ac.uk/resource/ensembl/eg2' ????

# and check transitive graph

$query = 'select ?uri from <http://rdf.ebi.ac.uk/resource/ensembl/> where { 
  <http://identifiers.org/ncbigene/ncbi1> <http://rdf.ebi.ac.uk/terms/ensembl/refers-to>+ ?uri .
  FILTER (?uri != <http://identifiers.org/ncbigene/ncbi1>)
}';

query($query,'uri',[
  'http://identifiers.org/hgnc/hgnc1',
  'http://identifiers.org/lrg/lrg1',
  'http://rdf.ebi.ac.uk/resource/ensembl/eg2'
  ],
  'Multi-hop transitive gene xrefs minus the deleted miscreant',
  $model);



done_testing;