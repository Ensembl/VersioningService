=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME
Bio::EnsEMBL::RDF::XrefReasoner

=head1 SYNOPSIS

use Bio::EnsEMBL::RDF::XrefReasoner;
my $reasoner = Bio::EnsEMBL::RDF::XrefReasoner->new();
    
=head1 DESCRIPTION

Provides a triplestore, with common xref pipeline functions.
Exists to provide easy wrapping in hive pipeline. It's not as clever as 
a formal reasoner, but the name seemed fitting.
  
=cut

package Bio::EnsEMBL::RDF::XrefReasoner;

use Moose;
use File::Slurp;
use Bio::EnsEMBL::RDF::FusekiWrapper;
use Bio::EnsEMBL::Mongoose::DBException;

has triplestore => ( isa => 'Object', is => 'ro', lazy => 1, builder => '_init_triplestore'); 
sub _init_triplestore {
  my $self = shift;
  # add a keepalive => 1 to allow the server to last beyond script duration. For debug
  return Bio::EnsEMBL::RDF::FusekiWrapper->new();
}

has prefixes => ( isa => 'Str', is => 'ro', 
  default => "PREFIX term: <http://rdf.ebi.ac.uk/terms/ensembl/>
              PREFIX ensembl: <http://rdf.ebi.ac.uk/resource/ensembl/>
              PREFIX dc: <http://purl.org/dc/elements/1.1/>
              PREFIX dcterms: <http://purl.org/dc/terms/>
              PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
              PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
              PREFIX obo: <http://purl.obolibrary.org/obo/>
");


sub load_general_data {
  my $self = shift;
  my @paths = @_;
  $self->triplestore->load_data([@paths]);
}

sub load_transitive_data {
  my $self = shift;
  my $paths = shift;
  my $graph_url = $self->triplestore->graph_url;
  my $condensed_graph = $graph_url;
  $condensed_graph =~ s/xref$//;
  $condensed_graph .= 'condensed';
  $self->triplestore->load_data($paths,$condensed_graph);
}

sub load_alignments {
  my $self = shift;
  my $alignment_path = shift; # folder containing all RefSeq alignment outputs
  my @files = read_dir($alignment_path, prefix => 1);
  @files = grep { /RefSeq/ } @files; # not interested in Uniprot alignments right now. They are only supporting information
  printf "Loading ALIGNMENT files: %s\n",join(',',@files);
  $self->triplestore->load_data([@files]);
}


sub nominate_transitive_xrefs {
  my $self = shift;

  my $graph_url = $self->triplestore->graph_url;
  my $condensed_graph = $graph_url;
  $condensed_graph =~ s/xref$//;
  $condensed_graph .= 'condensed'; # Where the transitive links will go
  print "Putting connected xrefs from $graph_url into $condensed_graph\n\n";
  # Start and end URIs are cosntrained to be genes by the SO_transcribed_to relation. Otherwise we xrefs for transcripts to any other type, e.g. ncbigene IDs
  my $sparql_select_best = "
    SELECT ?ens_uri ?ens_label ?link_type ?score ?other_uri ?other_label FROM <$graph_url> WHERE {
      ?ens_gene obo:SO_transcribed_to ?ens_uri .
      ?ens_uri term:refers-to ?xref .
      ?ens_uri dc:identifier ?ens_label .
      ?xref rdf:type ?link_type ;
            term:refers-to ?other_uri .
      OPTIONAL { ?xref term:score ?score }
      ?other_uri ^obo:SO_transcribed_to ?another_gene .
      ?other_uri dc:identifier ?other_label
    }
    ORDER BY ?ens_uri DESC(?link_type) DESC(?score)
    ";
  my $potentials_iterator = $self->triplestore->query($self->prefixes.$sparql_select_best);
  my $best = $self->pick_winners($potentials_iterator);
  $self->bulk_insert($condensed_graph,$best);
}

# Choose the best alignments for each Ensembl ID
# Only have to spot where equal candidates appear, or pick only the top one
sub pick_winners {
  my $self = shift;
  my $iterator = shift; # {ens_uri, link_type, score?, other_uri }
  Bio::EnsEMBL::Mongoose::DBException->throw("nominate_transitive_xrefs() Query returned 0 hits and cannot be filtered") unless $iterator->peek;
  my @winners;
  my @candidates;
  my $selected_items = 0;
  my $original_total = 0;
  while (!$iterator->finished) {
    # Buffer the set of xref options for one Ensembl ID
    my $first = $iterator->next;
    $original_total++;
    my $ens_uri = $first->{ens_uri}->value;
    # Collect all results pertaining to the same ID into a candidate buffer
    while (!$iterator->finished && $iterator->peek->{ens_uri}->value eq $ens_uri) {
      push @candidates,$iterator->next;
      $original_total++;
    }
    # Debug
    if (@candidates > 0) {
      print "####################\n";
      printf "Considering: %s\t%s\t%s\t%s\n",$first->{ens_label}->value, $first->{link_type}->value, ( exists $first->{score}) ? $first->{score}->value : '-',$first->{other_label}->value;
      print "-\n";
      for my $thing (@candidates) {
        no warnings 'uninitialized';
        printf "ens_uri %s\tscore %s\tlink type %s\tother_uri %s\n",$thing->{ens_label}->value, ( exists $thing->{score}) ? $thing->{score}->value : '-',$thing->{link_type}->value,$thing->{other_label}->value;
      }
      print "####################\n";
    }
    # Examine the competition for equal contenders
    # value takes the literal and extracts the value from its xsd:datatype and any quotes
    my $best_score;
    my $best_type = $first->{link_type}->value;
    $best_score = $first->{score}->value if exists $first->{score};
    my $our_uri = $first->{ens_uri}->value;
    my $our_label = $first->{ens_label}->value;
    my $other_uri = $first->{other_uri}->value;
    my $other_label = $first->{other_label}->value;
    push @winners,[$our_uri,$our_label,$other_uri,$other_label]; # Sorted results means top one is always a winner
    $selected_items++;
    # Find any joint winners
    while (my $candidate = shift @candidates) {
      last if (
           $candidate->{link_type}->value ne $best_type # types must be the same to join the bandwagon
        || ( exists $candidate->{score} && $candidate->{score}->value < $best_score) # scores must be equal
      );
      
      push @winners,[$our_uri,$our_label,$candidate->{other_uri}->value,$candidate->{other_label}->value];
      $selected_items++;
    }
    # And reset for the next ID in the buffer.
    @candidates = ();
  }
  
  printf "Selected %s best xrefs from %s overlaps, checksums and alignment matches\n",$selected_items,$original_total;
  return \@winners;
}

# Custom insert-builder for best alignments
sub bulk_insert {
  my $self = shift;
  my $graph = shift;
  $graph = $self->triplestore->graph_url unless $graph;
  my $hit_collection = shift;
  my $sparql_stub = "INSERT DATA { GRAPH <$graph> {";
  my $sparql_tail = "} }";
  printf "Size of hit-set = %d\n",scalar @$hit_collection;
  my $new_links = 0;

  my $fuseki = $self->triplestore;
  my $prefixes = $self->prefixes;
  my $iterations = scalar @$hit_collection;
  # Insert in chunks to avoid potential max post size limitations
  for (my $i = 0; $i < $iterations / 5000; $i++) {
    my $j = 0;
    my $hit;
    my $triples = '';
    while ($hit = shift @$hit_collection ) {
      $triples .= sprintf qq(<%s> term:refers-to <%s> .\n <%s> term:refers-to <%s> .\n <%s> dc:identifier "%s" .\n <%s> dc:identifier "%s" .\n), $hit->[0],$hit->[2],$hit->[2],$hit->[0],$hit->[0],$hit->[1],$hit->[2],$hit->[3]; # Ensembl points to Refseq and the converse
      $j++;
      last if $j == 5000;
      $new_links++;
    }
    if ($j > 0) {
      $fuseki->update($prefixes.$sparql_stub.$triples.$sparql_tail);
    }
  }
  printf "Added xrefs until %d remain\n",scalar @$hit_collection;
}

sub calculate_stats {
  my $self = shift;
  my $graph = shift;
  $graph = $self->triplestore->graph_url unless $graph;
  my $sparql_stats = "
    SELECT DISTINCT ?source_a ?source_b (COUNT(?source_b) as ?count) FROM <$graph> WHERE {
          ?entity dcterms:source ?source_a .
          ?entity term:refers-to ?xref .
          ?xref term:refers-to ?other .
          ?other dcterms:source ?source_b .
    } 
    GROUP BY ?source_a ?source_b 
    ORDER BY DESC(?count)";

  my $results = $self->triplestore->query($self->prefixes.$sparql_stats);
  return [$results->get_all];
}

sub pretty_print_stats {
  my $self = shift;
  my $stats = shift;

  printf "%20s %20s %s\n",'From','To','Count';
  while ( my $stat = shift @$stats) {
    printf "%20s %20s %d\n",$stat->{source_a}->value,$stat->{source_b}->value,$stat->{count}->value;
  }
}

sub extract_transitive_xrefs_for_id {
  my $self = shift;
  my $id = shift;
  my $graph_url = $self->triplestore->graph_url;
  my $condensed_graph = $graph_url;
  $condensed_graph =~ s/xref$//;
  $condensed_graph .= 'condensed';

  return $self->triplestore->sparql->recurse_xrefs($id,$condensed_graph);
}


__PACKAGE__->meta->make_immutable;
1;