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

# Loop through ordered results picking the best from each group
sub extract_max_values {
  my $results = shift;
  my @best_results;
  my $last_id = '';
  my $last_score = 0;
  foreach my $hit (@$results) {
    my $current_id = $hit->{ens_uri}->value;
    my $score = $hit->{score}->value;
    my $uri = $hit->{refseq_uri}->value;
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

sub pick_best_protein {
  my $transcript_results = shift; # These are final matches, i.e. more than one per ID is possible and intended.
  my $protein_results = shift; # These are unfiltered matches, so includes suboptimal results
  my @best;
  my $last_id;
  my $last_score;
  my $ens_uri;
  my %transcripts;
  # note "Raw data to choose from:";
  # note (Dumper $transcript_results);
  # note (Dumper $protein_results);
  # build a lookup for ensembl->refseq transcript links
  foreach my $result (@$transcript_results) {
    my $ens_uri = $result->[0];
    my $refseq_uri = $result->[1];
    my $score = $result->[2];
    
    $transcripts{$ens_uri}->{$refseq_uri} = $score ;
  }
  # now scan through the protein hits, cross-checking against the transcripts for matches

  my @buffer;
  foreach my $hit (@$protein_results) {
    my $refseq_protein = $hit->{refseq_uri}->value;

    if ($last_id eq $refseq_protein || @buffer == 0) {
      push @buffer, {
        ens_transcript => $hit->{ens_transcript}->value,
        ens_protein => $hit->{ens_uri}->value,
        score => $hit->{score}->value,
        refseq_transcript => $hit->{refseq_transcript}->value,
        refseq_protein => $refseq_protein
      };
      $last_id = $refseq_protein;
    } else {
      $last_id = $refseq_protein;
      # sort buffer
      my @best_in_protein = pick_best(\@buffer,\%transcripts);
      # record best entries
      push @best, @best_in_protein;
      # flush buffer
      @buffer = ();
    }
  }
  my @best_in_protein = pick_best(\@buffer,\%transcripts);
  # record best entries
  push @best, @best_in_protein;
  return \@best;
}

sub pick_best {
  my $candidates = shift; # protein matches for a given ensembl protein
  my $transcripts = shift; # All transcript pairs plus scores
  # note(Dumper $transcripts);
  # Add an evidence code so as to know whether there is a transcript xref to match the protein xref
  # 2 = fully supported by transcripts
  # 1 = no support
  # 0 = contrary evidence, i.e. transcript links to a completely different transcript
  foreach my $candidate (@$candidates) {
    if (exists $transcripts->{ $candidate->{ens_transcript} }) {
      if ( grep { $_ eq $candidate->{refseq_transcript} }
              keys %{ $transcripts->{$candidate->{ens_transcript}} } ) {
        $candidate->{evidence} = 2
      } else {
        $candidate->{evidence} = 0
      }
    } else {
      $candidate->{evidence} = 1;
    }
  }
  # note "Added evidence scores";
  # note (Dumper $candidates);
  # Now order candidates by their evidence
  $candidates = [sort { $b->{evidence} <=> $a->{evidence} || $b->{score} <=> $a->{score} } @$candidates];
  # note(Dumper $candidates);
  my $cutoff = $candidates->[0]->{evidence};
  my $high_score = $candidates->[0]->{score};
  return if ($cutoff == 0); # None are good enough
  return grep { $_->{evidence} == $cutoff && $_->{score} == $high_score } @$candidates;
}

# Prepare RefSeq alignment hits in order
my $sparql_all_alignments = 'SELECT ?ens_uri ?score ?refseq FROM <http://rdf.ebi.ac.uk/resource/ensembl_full/> WHERE {
    ?xref rdf:type term:Alignment .
    ?xref term:refers-to ?refseq .
    ?xref term:score ?score .
    ?ens_uri term:refers-to ?xref .
  } ORDER BY DESC(?score)';
my @results = query($sparql_all_alignments);
# note "RefSeq alignment hits";
# note(Dumper @results);
cmp_ok(scalar @results, '==', 4, 'Four scores to utilise when deciding where to assign RefSeq Xrefs');

 # note $full_fat_ttl;
# Get the pairings of RefSeq and Ensembl IDs (any feature type)
my $sparql_refseq = 'SELECT ?refseq_uri ?score ?ens_uri FROM <http://rdf.ebi.ac.uk/resource/ensembl_full/> WHERE {
    ?ens_uri term:refers-to ?xref ;
          obo:SO_transcribed_from ?ensgene .
    ?xref rdf:type term:Alignment ;
          term:score ?score ;
          term:refers-to ?refseq_uri .
  } ORDER BY ?refseq_uri DESC(?score)';

my @refseq_pairs = query($sparql_refseq);
my $transcript_pairings = extract_max_values(\@refseq_pairs);
# note(Dumper $transcript_pairings);
cmp_ok(scalar @$transcript_pairings, '==', 2, 'Two mappings from enst1 to Refseq transcripts');

# Get the related gene, transcript and protein for all things.
my $sparql_test_gene_model = 'SELECT ?gene ?transcript ?protein FROM <http://rdf.ebi.ac.uk/resource/ensembl_full/> WHERE {
  ?gene obo:SO_transcribed_to ?transcript .
  ?transcript obo:SO_translates_to ?protein .
}';
my %structure;
my @ens_features = query($sparql_test_gene_model);
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

#### Now combine alignment score filtering with feature association

# 1. select best hit transcript for given ensembl transcript
# -----
# 2. select best protein hit for given ensembl protein, given that the matching transcript is also best choice.

my $sparql = 'SELECT ?refseq_uri ?refseq_transcript ?score ?ens_uri ?ens_transcript FROM <http://rdf.ebi.ac.uk/resource/ensembl_full/> WHERE {
    ?ens_uri obo:SO_translation_of ?ens_transcript .
    ?ens_uri term:refers-to ?xref .
    ?xref rdf:type term:Alignment ;
          term:score ?score ;
          term:refers-to ?refseq_uri .
    ?refseq_uri obo:SO_translation_of ?refseq_transcript . 

  } ORDER BY ?refseq_uri DESC(?score)';

my @proteins = query($sparql);
my $best_results = pick_best_protein($transcript_pairings,\@proteins);

# note(Dumper $best_results);

cmp_ok(scalar @$best_results, '==', 1, 'One protein pair returned of the two possible matches');
my $hit = $best_results->[0];
is($hit->{ens_protein}, 'http://rdf.ebi.ac.uk/resource/ensembl.protein/ensp1', 'ENSP1 chosen');
is($hit->{refseq_protein}, 'http://identifiers.org/refseq/np1', 'NP1 chosen');


done_testing();