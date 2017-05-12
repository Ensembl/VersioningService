use strict;
use Data::Dumper;
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

my $full_fat_ttl;
my $ignoramous_fh = IO::String->new($full_fat_ttl);
my $other_rdf_writer = Bio::EnsEMBL::Mongoose::Serializer::RDF->new(handle => $ignoramous_fh ,config_file => "$Bin/../conf/test.conf");

$rdf_writer->print_source_meta;
$other_rdf_writer->print_source_meta;
# Thought experiment for correctly selecting RefSeq transcripts and proteins where there are possibilities for a disconnect
# between transcript and proteins as a result of their alignment score

my @records;
push @records, 
  [
    'RefSeq_mRNA', Bio::EnsEMBL::Mongoose::Persistence::Record->new({ 
      id => 'nm1',
      accessions => ['nm1'],
      protein_name => 'np1',
      gene_name => '101'
    })
  ]
;

foreach my $write_me (@records) {
  my ($source,$record) = @$write_me;
  $rdf_writer->print_slimline_record($record,$source);
  $other_rdf_writer->print_record($record,$source);
}

$other_rdf_writer->print_alignment_xrefs('enst1','ensembl_transcript','nm1','RefSeq_mRNA',0.99);
$other_rdf_writer->print_alignment_xrefs('enst1','ensembl_transcript','nm2','RefSeq_mRNA',0.90);
$other_rdf_writer->print_alignment_xrefs('ensp1','ensembl_protein','np1','RefSeq_peptide',0.98);
$other_rdf_writer->print_alignment_xrefs('ensp2','ensembl_protein','np1','RefSeq_peptide',0.98);

$other_rdf_writer->print_gene_model_link('ensg1','ensembl','enst1','ensembl_transcript','ensp1','ensembl_protein');
$other_rdf_writer->print_gene_model_link('ensg1','ensembl','enst2','ensembl_transcript','ensp2','ensembl_protein');

my $store = RDF::Trine::Store::Memory->new();
my $model = RDF::Trine::Model->new($store);
my $parser = RDF::Trine::Parser->new('turtle');
$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ensembl_full/',$full_fat_ttl,$model);
ok($model);

sub query {
  my ($sparql) = @_;
  my $prefixes = $rdf_writer->compatible_name_spaces();
  my $query = RDF::Query->new($prefixes.$sparql);
  note (RDF::Query->error) unless $query;
  my $iterator = $query->execute($model);
  my @results = $iterator->get_all;
  return @results;
}

# Prepare RefSeq alignment hits in order
my $sparql = 'SELECT ?uri ?score FROM <http://rdf.ebi.ac.uk/resource/ensembl_full/> WHERE {
    ?xref rdf:type term:Alignment .
    ?xref term:refers-to ?refseq .
    ?xref term:score ?score .
    ?uri term:refers-to ?xref .
  } ORDER BY DESC(?score)';
my @results = query($sparql);

# note "RefSeq alignment hits";
# note(Dumper @results);
cmp_ok(scalar @results, '==', 4, 'Four scores to utilise when deciding where to assign RefSeq Xrefs');

 # note $full_fat_ttl;
# Get the pairings of RefSeq and Ensembl IDs
$sparql = 'SELECT ?refseq_uri ?score ?ens_uri FROM <http://rdf.ebi.ac.uk/resource/ensembl_full/> WHERE {
    ?refseq_uri term:refers-to ?xref .
    ?xref rdf:type term:Alignment ;
          term:score ?score ;
          term:refers-to ?ens_uri .

  } ORDER BY ?refseq_uri DESC(?score)';

my @refseq_pairs = query($sparql);
# note(Dumper @refseq_pairs);

# Get the related gene, transcript and protein for all things.
$sparql = 'SELECT ?gene ?transcript ?protein FROM <http://rdf.ebi.ac.uk/resource/ensembl_full/> WHERE {
  ?gene obo:SO_transcribed_to ?transcript .
  ?transcript obo:SO_translates_to ?protein .
}';
my %structure;
my @ens_features = query($sparql);
# note "Gene, transcript, protein triplet";
# note Dumper(@ens_features);
foreach my $combo (@ens_features) {
  # note Dumper($combo);
  my $gene_key = $combo->{gene}->value;
  my $transcript_key = $combo->{transcript}->value;
  my $protein_key = $combo->{protein}->value;
  $structure{$gene_key}->{$transcript_key}->{$protein_key} = 1;
}
# note(Dumper \%structure);

is_deeply(\%structure, { 
  'http://rdf.ebi.ac.uk/resource/ensembl/ensg1' => {
    'http://rdf.ebi.ac.uk/resource/ensembl.transcript/enst1' => {
      'http://rdf.ebi.ac.uk/resource/ensembl.protein/ensp1' => 1 
    }, 
    'http://rdf.ebi.ac.uk/resource/ensembl.transcript/enst2' => {
      'http://rdf.ebi.ac.uk/resource/ensembl.protein/ensp2' => 1
    }
  },
  'http://identifiers.org/ncbigene/101' => {
    'http://identifiers.org/refseq/nm1' => {
      'http://identifiers.org/refseq/np1' => 1
    }
  }
}, 'Relationships between genes, transcripts and proteins correct as extracted from RDF');






done_testing();