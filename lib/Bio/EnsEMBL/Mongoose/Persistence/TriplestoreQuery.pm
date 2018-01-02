=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head2 DESCRIPTION

TriplestoreQuery - a query object to run general and pre-cooked SPARQL queries against an HTTP-accessible triplestore

=cut

package Bio::EnsEMBL::Mongoose::Persistence::TriplestoreQuery;
use Moose;
use RDF::Query::Client;
use Bio::EnsEMBL::RDF::RDFlib qw/compatible_name_spaces prefix u/;
use Bio::EnsEMBL::Mongoose::DBException;

has triplestore_url => (
  is => 'rw',
  isa => 'Str',
  default => 'http://127.0.0.1:8890/'
);

has query_endpoint => ( is => 'ro', isa => 'Str', default => 'sparql');
has update_endpoint => ( is => 'ro', isa => 'Str', default => 'update');

# name of named graph in triplestore
has graph => (
  is => 'rw',
  isa => 'Maybe[Str]',
);

with 'Bio::EnsEMBL::Mongoose::Persistence::Query';

# returns a result iterator
sub query {
  my $self = shift;
  my $query = shift;
  my $config = $self->query_parameters;
  # TODO: implement support for query modification with parameters
  #       species_name = graph choice, result_size = LIMIT, ids mapped to Ensembl URIs?
  # print "Query received: $query\n";
  # print "Sending query to: ".$self->triplestore_url."\n";
  my $sparql = RDF::Query::Client->new($query);
  my $result_iterator = $sparql->execute($self->triplestore_url.$self->query_endpoint);
  my $error = $sparql->error();
  if ($error) { Bio::EnsEMBL::Mongoose::DBException->throw($error.' '.$sparql->http_response) }
  return $result_iterator;
}

sub update {
  my $self = shift;
  my $query = shift;
  my $config = $self->query_parameters;
  my $sparql = RDF::Query::Client->new($query);
  my $result_iterator = $sparql->execute($self->triplestore_url.$self->update_endpoint, { ContentType => 'application/sparql-update' });
  my $error = $sparql->error();
  if ($sparql->http_response->code != 204 && $error) { Bio::EnsEMBL::Mongoose::DBException->throw($error.' '.$sparql->http_response->code) }
}


# Query graph for an ID and all related xrefs (outbound links), returns a list of names
sub recurse_xrefs {
  my $self = shift;
  my $id = shift;
  my $graph_name = shift;
  if ($graph_name) {
    $graph_name = 'FROM <'.$graph_name.'>';
  } else {
    $graph_name = $self->generate_graph_name;
  }
  my $result_hash = {};
  my $query = sprintf qq(%s\nSELECT DISTINCT ?xref_label %s {
    ?o dc:identifier "%s" .
    ?o term:refers-to+ ?e .
    ?e dc:identifier ?xref_label.
    }), compatible_name_spaces(),$graph_name,$id;
  # print $query."\n";
  my $iterator = $self->query($query);

  my @xrefs = ();
  return unless defined $iterator;
  # map result objects into array of xref labels
  while (my $result = $iterator->next) {
    # print Dumper $result_iterator;
    my $string = $result->{xref_label}->as_string;
    $string =~ s/"//g;
    push @xrefs,$string;
  }
  return \@xrefs;
}

sub recurse_mini_graph {
  my $self = shift;
  my $id = shift;
  my $result_hash = {};
  my $graph_name = $self->generate_graph_name;
  my $query = sprintf qq(%s\nSELECT DISTINCT ?xref_label %s {
    ?xref_label term:refers-to+ ensembl:%s .
    }), compatible_name_spaces(),$graph_name,$id;
  # print $query."\n";
  my $iterator = $self->query($query);

  my @xrefs = ();
  return unless defined $iterator;
  # map result objects into array of xref labels
  while (my $result = $iterator->next) {
    # print Dumper $result_iterator;
    my $string = $result->{xref_label}->as_string;
    # $string =~ s/"//g;
    push @xrefs,$string;
  }
  return \@xrefs;
}

# Query graph for all inbound links to a single known node
sub get_all_linking_xrefs {
  my $self = shift;
  my $id = shift;
  my $result_hash = {};
  my $graph_name = $self->generate_graph_name;
  my $query = sprintf qq(%s\nSELECT DISTINCT ?xref_label %s {
    ?ref dc:identifier "%s" .
    ?o term:refers-to+ ?ref .
    ?o dc:identifier ?xref_label.
    }), compatible_name_spaces(),$graph_name,$id;
  # print $query."\n";
  my $iterator = $self->query($query);

  my @xrefs = ();
  return unless defined $iterator;
  # map result objects into array of xref labels
  while (my $result = $iterator->next) {
    # print Dumper $result_iterator;
    my $string = $result->{xref_label}->as_string;
    $string =~ s/"//g;
    push @xrefs,$string;
  }
  return \@xrefs;
}

sub generate_graph_name {
  my $self = shift;
  my $graph_name = $self->graph;
  if ($graph_name) {
    $graph_name = "FROM <".$graph_name.">" ;
  } else {
    $graph_name = "";
  }
  return $graph_name;
}

# Loop through ordered results picking the best from each group
sub extract_max_values {
  my ($self,$graph_name) = @_;
  my $prefixes = compatible_name_spaces();
  my $sparql = "SELECT ?refseq_uri ?score ?ens_uri FROM <$graph_name> WHERE {
    ?ens_uri term:refers-to ?xref ;
          obo:SO_transcribed_from ?ensgene .
    ?xref rdf:type term:Alignment ;
          term:score ?score ;
          term:refers-to ?refseq_uri .
  } ORDER BY ?refseq_uri DESC(?score)";

  my $iterator = $self->query($prefixes.$sparql);
  my @results = $iterator->get_all;
  my @best_results;
  my $last_id = '';
  my $last_score = 0;
  foreach my $hit (@results) {
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

# transcript pairs come directly from extract_max_values() but are used for more than just picking the best protein
# These are final matches, i.e. more than one per ID is possible and intended.
sub pick_best_protein {
  my ($self,$graph_name,$transcript_pairs) = @_;

  my $prefixes = compatible_name_spaces();

  my $sparql = "SELECT ?refseq_uri ?refseq_transcript ?score ?ens_uri ?ens_transcript FROM <$graph_name> WHERE {
    ?ens_uri obo:SO_translation_of ?ens_transcript .
    ?ens_uri term:refers-to ?xref .
    ?xref rdf:type term:Alignment ;
          term:score ?score ;
          term:refers-to ?refseq_uri .
    ?refseq_uri obo:SO_translation_of ?refseq_transcript . 

  } ORDER BY ?refseq_uri DESC(?score)";

  my $iterator = $self->query($prefixes.$sparql);

  my $protein_pairs = $iterator->get_all;
  
  my @best;
  my $last_id;
  my $last_score;
  my $ens_uri;
  my %transcripts;

  # build a lookup for ensembl->refseq transcript links
  foreach my $result (@$transcript_pairs) {
    my $ens_uri = $result->[0];
    my $refseq_uri = $result->[1];
    my $score = $result->[2];
    
    $transcripts{$ens_uri}->{$refseq_uri} = $score ;
  }
  # now scan through the protein hits, cross-checking against the transcripts for matches

  my @buffer;
  foreach my $hit (@$protein_pairs) {
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
      my @best_in_protein = $self->pick_best(\@buffer,\%transcripts);
      # record best entries
      push @best, @best_in_protein;
      # flush buffer
      @buffer = ();
    }
  }
  my @best_in_protein = $self->pick_best(\@buffer,\%transcripts);
  # record best entries
  push @best, @best_in_protein;
  return \@best;
}


# Given output of pick_best_protein and a list of best transcripts from extract_max_values
# Look for supporting evidence and rank the results to provide a list of preferred links
sub pick_best {
  my $self = shift;
  my $candidates = shift; # protein matches for a given ensembl protein
  my $transcripts = shift; # All transcript pairs plus scores

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

  # Now order candidates by their evidence
  $candidates = [sort { $b->{evidence} <=> $a->{evidence} || $b->{score} <=> $a->{score} } @$candidates];
  # note(Dumper $candidates);
  # Pick out any hits that make the cutoff and have equal merit
  my $cutoff = $candidates->[0]->{evidence};
  my $high_score = $candidates->[0]->{score};
  return if ($cutoff == 0); # None are good enough
  return grep { $_->{evidence} == $cutoff && $_->{score} == $high_score } @$candidates;
}


1;
