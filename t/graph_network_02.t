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

# Look into consequences of different kinds of xrefs, and querying ability to select and infer.
# This testcase represents the process by which one would infer transitive xrefs via alignments

sub xrefs {
  my $list_ref = shift;
  my @proper_xrefs;
  foreach my $xref (@$list_ref) {
    push @proper_xrefs, Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new($xref);
  }
  return \@proper_xrefs;
}

my $store = RDF::Trine::Store::Memory->new();
my $model = RDF::Trine::Model->new($store);
my $parser = RDF::Trine::Parser->new('turtle');

sub query {
  my ($query,$var_name,$expected_accessions,$test_name) = @_;
  my $prefixes = $rdf_writer->compatible_name_spaces();
  $query = RDF::Query->new($prefixes.$query);
  note (RDF::Query->error) unless $query;
  my $iterator = $query->execute($model);
  my @results = $iterator->get_all;
  # note Dumper @results;
  cmp_deeply([map {$_->{$var_name}->value} @results],bag(@$expected_accessions),$test_name);
}

sub ordered_query {
  my ($query,$var_name,$expected_accessions,$test_name) = @_;
  my $prefixes = $rdf_writer->compatible_name_spaces();
  $query = RDF::Query->new($prefixes.$query);
  $query->error;
  my $iterator = $query->execute($model);
  my @results = $iterator->get_all;
  cmp_deeply([map {$_->{$var_name}->value} @results],$expected_accessions, $test_name);
}
my @records;

sub extract_max_values {
  my $iterator = shift;
  my @best_results;
  my $last_id = '';
  my $last_score = 0;
  while (my $hit = $iterator->next) {
    my $current_id = $hit->{ens_uri}->value;
    my $score = $hit->{score}->value;
    my $uri = $hit->{uri}->value;
    if ($last_id eq $current_id) {
      next if ($score < $last_score);
      $last_score = $score;
      push @best_results,[$current_id,$uri,$score];
    } else {
      $last_id = $current_id;
      push @best_results,[$current_id,$uri,$score]; # new top hit
    }
  }
  return \@best_results;
}

push @records,['RefSeq_mRNA', Bio::EnsEMBL::Mongoose::Persistence::Record->new({ 
  id => 'nm1',
  accessions => [qw/nm1/],
  xref => xrefs([
    {source => 'miRBase',active => 1,id => 'mir1'}, 

  ])
})
];

$rdf_writer->print_source_meta;
$other_rdf_writer->print_source_meta;
# Dump regular xrefs in full and condensed form
foreach my $write_me (@records) {
  my ($source,$record) = @$write_me;
  $rdf_writer->print_slimline_record($record,$source);
  $other_rdf_writer->print_record($record,$source);
}

# Now print some token alignments to test against

$other_rdf_writer->print_alignment_xrefs('enst1','ensembl_transcript','nm1','RefSeq_mRNA',0.99);
$other_rdf_writer->print_alignment_xrefs('enst1','ensembl_transcript','nm2','RefSeq_mRNA',0.95);
$other_rdf_writer->print_alignment_xrefs('enst1','ensembl_transcript','nm3','RefSeq_mRNA',0.99);
$other_rdf_writer->print_alignment_xrefs('enst1','ensembl_transcript','nm4','RefSeq_mRNA',0.80);

$other_rdf_writer->print_alignment_xrefs('enst2','ensembl_transcript','nm5','RefSeq_mRNA',0.85);
$other_rdf_writer->print_alignment_xrefs('enst2','ensembl_transcript','nm6','RefSeq_mRNA',0.84);

# note $full_fat_ttl;
# Consume the full form and analyse alignments
$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ensembl_full/',$full_fat_ttl,$model);
ok($model);

my $prefixes = $rdf_writer->compatible_name_spaces();
my $sparql = 'SELECT ?ens_uri ?uri ?score FROM <http://rdf.ebi.ac.uk/resource/ensembl_full/> WHERE {
  ?ens_uri term:refers-to ?xref .
  ?xref rdf:type term:Alignment ;
        term:score ?score ;
        term:refers-to ?uri .
} 
ORDER BY ?ens_uri DESC(?score)
  ';

# Attempt to collect best hit(s) per ID, SPARQL makes this apparently impossible for more than one ID at a time
# Better to filter the list in regular code instead of running many complex queries
# $sparql = 'SELECT ?ens_uri ?uri ?score FROM <http://rdf.ebi.ac.uk/resource/ensembl_full/> WHERE {
#     ?ens_uri term:refers-to ?xref .
#     ?xref rdf:type term:Alignment ;
#         term:score ?score ;
#         term:refers-to ?uri .
#     { SELECT ?ens_uri ?score WHERE {
#         ?ens_uri term:refers-to ?xref_x . 
#         ?xref_x rdf:type term:Alignment ;
#               term:score ?score .
#       } ORDER BY ?ens_uri DESC(?score) LIMIT 1
#     }
#   }
#   ';

my $query = RDF::Query->new($prefixes.$sparql);
note (RDF::Query->error) unless $query;
my $iterator = $query->execute($model);
my $top_hits = extract_max_values($iterator);
# my @results = $iterator->get_all;
# note Dumper $top_hits;

cmp_deeply($top_hits,bag(
    ['http://rdf.ebi.ac.uk/resource/ensembl.transcript/enst1','http://identifiers.org/refseq/nm1',0.99],
    ['http://rdf.ebi.ac.uk/resource/ensembl.transcript/enst1','http://identifiers.org/refseq/nm3',0.99],
    ['http://rdf.ebi.ac.uk/resource/ensembl.transcript/enst2','http://identifiers.org/refseq/nm5',0.85]
  ),
  'Results pruned to best or equal best where appropriate'
);

# Generate additional condensed xrefs from alignment resolution.
foreach my $hit (@$top_hits) {
  my $uri = $hit->[0];
  my $xref = $hit->[1];
  my $uri_label = $uri;
  $uri_label =~ s/.+\///;
  my $xref_label = $xref;
  $xref_label =~ s/.+\///;
  print "Change $uri to $uri_label\n";
  print "Change $xref to $xref_label\n";
  $rdf_writer->print_slimline_alignment_xrefs($uri_label,'ensembl_transcript',$xref_label,'RefSeq_mRNA');
}

# Consume condensed RDF from both regular xref output AND alignment result
$parser->parse_into_model('http://rdf.ebi.ac.uk/resource/ensembl/', $ttl, $model);
# note $ttl;
$sparql = 'SELECT ?id FROM <http://rdf.ebi.ac.uk/resource/ensembl/> WHERE { 
  <http://rdf.ebi.ac.uk/resource/ensembl.transcript/enst1> term:refers-to+ ?uri .
  ?uri dc:identifier ?id .
}';

query($sparql,'id',[qw/enst1 nm1 nm3 mir1/]);



done_testing;