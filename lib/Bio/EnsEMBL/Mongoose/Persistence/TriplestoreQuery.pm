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
  default => 'http://127.0.0.1:8890/sparql'
);

has result_set => (
    is => 'rw',
    lazy => 1,
    default => sub {
        
    }
);
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
  my $result_iterator = $sparql->execute($self->triplestore_url);
  my $error = $sparql->error();
  if ($error) { Bio::EnsEMBL::Mongoose::DBException->throw($error.' '.$sparql->http_response) }
  $self->result_set($result_iterator);
}

sub next_result {
  my $self = shift;
  if ($self->result_set) {
    return $self->result_set->next;
  } else {
    return;
  }
}

# Query graph for an ID and all related xrefs (outbound links), returns a list of names
sub recurse_xrefs {
  my $self = shift;
  my $id = shift;
  my $result_hash = {};
  my $graph_name = $self->generate_graph_name;
  my $query = sprintf qq(%s\nSELECT DISTINCT ?xref_label %s {
    ?o dc:identifier "%s" .
    ?o term:refers-to+ ?e .
    ?e dc:identifier ?xref_label.
    }), compatible_name_spaces(),$graph_name,$id;
  # print $query."\n";
  $self->query($query);

  my @xrefs = ();
  return unless defined $self->result_set;
  # map result objects into array of xref labels
  while (my $result = $self->next_result) {
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
  $self->query($query);

  my @xrefs = ();
  return unless defined $self->result_set;
  # map result objects into array of xref labels
  while (my $result = $self->next_result) {
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
  $self->query($query);

  my @xrefs = ();
  return unless defined $self->result_set;
  # map result objects into array of xref labels
  while (my $result = $self->next_result) {
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

1;
