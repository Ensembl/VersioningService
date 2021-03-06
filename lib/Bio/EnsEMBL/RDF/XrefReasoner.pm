=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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
use File::Slurper 'read_dir';
use Bio::EnsEMBL::RDF::FusekiWrapper;
use Bio::EnsEMBL::Mongoose::DBException;

has triplestore => ( isa => 'Object', is => 'ro', lazy => 1, builder => '_init_triplestore'); 
sub _init_triplestore {
  my $self = shift;
  # add a keepalive => 1 to allow the server to last beyond script duration. For debug
  return Bio::EnsEMBL::RDF::FusekiWrapper->new(keepalive => $self->keepalive, heap => $self->memory);
}

has keepalive => ( isa => 'Bool', is => 'ro', default => 0);
has memory => ( isa => 'Int', is => 'ro', default => 16);

has prefixes => ( isa => 'Str', is => 'ro', 
  default => "PREFIX term: <http://rdf.ebi.ac.uk/terms/ensembl/>
              PREFIX ensembl: <http://rdf.ebi.ac.uk/resource/ensembl/>
              PREFIX dc: <http://purl.org/dc/elements/1.1/>
              PREFIX dcterms: <http://purl.org/dc/terms/>
              PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
              PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
              PREFIX obo: <http://purl.obolibrary.org/obo/>
");

has debug_fh => ( is => 'ro', predicate => 'debugging');

# Take RDF and load it into the default graph
sub load_general_data {
  my $self = shift;
  my @paths = @_;
  $self->triplestore->load_data([@paths]);
}

# Take RDF and load it into a non-default graph for separate consideration
sub load_transitive_data {
  my $self = shift;
  my $paths = shift;
  my $graph_url = $self->triplestore->graph_url;
  my $condensed_graph = $self->condensed_graph_name($graph_url);
  $self->triplestore->load_data($paths,$condensed_graph);
}

# Batch load lots of files from a given folder
sub load_alignments {
  my $self = shift;
  my $alignment_path = shift; # folder containing all RefSeq alignment outputs
  my @files = read_dir($alignment_path);
  @files = map { $alignment_path.'/'.$_ } grep { /RefSeq/ } @files; # not interested in Uniprot alignments right now. They are only supporting information
  # printf "Loading ALIGNMENT files: %s\n",join(',',@files);
  $self->triplestore->load_data([@files]);
}


# Choose which xrefs get to be treated as "the same thing", in addition to anything loaded with load_transitive_data()
sub nominate_transitive_xrefs {
  my $self = shift;

  my $graph_url = $self->triplestore->graph_url;
  my $condensed_graph = $self->condensed_graph_name($graph_url);

  print "Putting connected xrefs from $graph_url into $condensed_graph\n\n";
  
  # Select Ensembl Transcripts that have xrefs to any RefSeq ID (multiple peptide sources are part of the set)
  # AND localise to those that have genes as well. This eliminates older data for which there is no gene model remaining
  # Could stop localising on the Ensembl side, as the constraint is redundant with feature type
  my $sparql_select_best = "
    SELECT ?ens_uri ?ens_label ?link_type ?score ?other_uri ?other_label FROM <$graph_url> WHERE {
      ?ens_gene obo:SO_transcribed_to ?ens_uri .
      ?ens_uri dcterms:source <http://rdf.ebi.ac.uk/resource/ensembl.transcript/> .
      ?ens_uri term:refers-to ?xref .
      ?ens_uri dc:identifier ?ens_label .
      ?xref rdf:type ?link_type ;
            term:refers-to ?other_uri .
      ?other_uri term:generic-source <http://identifiers.org/refseq/> .
      OPTIONAL { ?xref term:score ?score }
      ?other_uri ^obo:SO_transcribed_to ?another_gene .
      ?other_uri dc:identifier ?other_label
    }
    ORDER BY ?other_uri DESC(?link_type) DESC(?score)
    ";
  my $potentials_iterator = $self->triplestore->query($self->prefixes.$sparql_select_best);
  my $best = $self->pick_winners($potentials_iterator);
  my @copy = @$best;
  $self->bulk_insert($condensed_graph,\@copy);
  my $best_proteins = $self->nominate_refseq_proteins($best);
  $self->bulk_insert($condensed_graph, $best_proteins);
}


# Choose which RefSeq proteins get to be transitive xrefs, based on their alignments AND whether their transcripts were paired up
# Returns the list of winners to be stored back in the transitive graph
sub nominate_refseq_proteins {
  my $self = shift;
  my $best_transcripts = shift;
  my $graph_url = $self->triplestore->graph_url;

  # Build a lookup for transcript pairings we want to match using the output of the transcript assignment
  my %transcript_lookup;
  foreach my $pairing (@$best_transcripts) {
    $transcript_lookup{$pairing->[3] }->{ $pairing->[1]} = 1 ;
  }
  printf "!!!!Built lookup with %d RefSeq labels\n",scalar(keys %transcript_lookup);
  
  # Select protein match possibilities. These should be only alignments
  # Get the Ensembl proteins with links to any RefSeq ID which is also a translation of something
  # RefSeq proteins are only aligned, no coordinate overlaps or other types
  print "Deciding which proteins to link together from RefSeq to Ensembl\n";
  my $sparql = "
  SELECT ?ens_uri ?ens_label ?score ?other_uri ?other_label ?refseq_transcript_id ?ens_transcript_id FROM <$graph_url> WHERE {
    ?ens_uri obo:SO_translation_of ?ens_transcript .
    ?ens_transcript dc:identifier ?ens_transcript_id .
    ?ens_uri dcterms:source <http://rdf.ebi.ac.uk/resource/ensembl.protein/> .
    ?ens_uri dc:identifier ?ens_label .
    ?ens_uri term:refers-to ?xref .
    ?xref rdf:type term:Alignment ;
          term:score ?score ;
          term:refers-to ?other_uri .
    ?other_uri obo:SO_translation_of ?refseq_transcript .
    ?refseq_transcript dc:identifier ?refseq_transcript_id .
    ?other_uri term:generic-source <http://identifiers.org/refseq/> .
    ?other_uri dc:identifier ?other_label .
  } 
  ORDER BY ?other_uri DESC(?score)
    "; 
  my $iterator = $self->triplestore->query($self->prefixes.$sparql);

  my @winners;
  my @candidates;
  my $selected_items = 0;
  my $original_total = 0;
  while (!$iterator->finished) {
    my $first = $iterator->peek;
    @candidates = ();

    # Get the initially winning options
    my $refseq_uri = $first->{other_uri}->value;
    my $refseq_transcript_label = $first->{refseq_transcript_id}->value;
    # Collect all results pertaining to the same ID into a candidate buffer
    while (!$iterator->finished && $iterator->peek->{other_uri}->value eq $refseq_uri) {
      my $candidate = $iterator->next;

      my $refseq_label = $candidate->{other_label}->value;
      my $ens_uri = $candidate->{ens_uri}->value;
      my $ens_label = $candidate->{ens_label}->value;
      my $score = $candidate->{score}->value; # All protein xrefs are alignments and have scores
      my $refseq_transcript_label = $candidate->{refseq_transcript_id}->value;
      my $ens_transcript_label = $candidate->{ens_transcript_id}->value;
      my $transcript_score; # +ve = transcript pairing supports protein pairing

      if (exists $transcript_lookup{$refseq_transcript_label}) {
        my $ideal_transcripts = $transcript_lookup{$refseq_transcript_label};

        if (exists $ideal_transcripts->{$ens_transcript_label} ) {
          $transcript_score = 1; # confirmation this is a good protein pair to make
        } else {
          $transcript_score = -1; # there are transcript pairings but not for this protein pairing
        }
      } else {
        $transcript_score = 0; # No evidence exists to support or contradict this protein pairing
      }

      push @candidates,[$ens_uri,$ens_label,$refseq_uri,$refseq_label,$score,$transcript_score];
      $original_total++;

    }

    # Re-order candidates by their transcript evidence and of course alignment score
    @candidates = sort { 
         $b->[5] <=> $a->[5]  
      || $b->[4] <=> $a->[4]
    } @candidates;
    # And cream off the best
    for my $candidate (@candidates){
      printf "%s\t%s\t%.2f\t%d\n",
        $candidate->[1],
        $candidate->[3],
        $candidate->[4],
        $candidate->[5];
    }
    

    my $best_score = $candidates[0]->[4];
    my $best_transcript_score = $candidates[0]->[5];

    # Candidates with transcript evidence can have any score, candidates without must have identity higher than 90%
    # Candidates wtih contrary evidence disappear. These could be disposed of earlier but the debug is more obscure
    if ($best_transcript_score == 0 && $best_score > 0.9) {
      push @winners, grep { $_->[4] == $best_score } @candidates;
    } elsif ( $best_transcript_score == 1) {
      push @winners, grep { $_->[5] == $best_transcript_score} @candidates;
    }

  }
  return \@winners;
}


# Choose the best matches for each RefSeq transcript ID
# Only have to spot where equal candidates appear, or pick just the top one
sub pick_winners {
  my $self = shift;
  my $iterator = shift; # {ens_uri, link_type, score?, other_uri }
  Bio::EnsEMBL::Mongoose::DBException->throw("nominate_transitive_xrefs() Query returned 0 hits and cannot be filtered") unless $iterator->peek;
  my @winners;
  my @candidates;
  my $selected_items = 0;
  my $original_total = 0;
  while (!$iterator->finished) {
    # Buffer the set of xref options for one RefSeq ID
    my $first = $iterator->next;
    $original_total++;
    my $other_uri = $first->{other_uri}->value;
    # Collect all results pertaining to the same ID into a candidate buffer
    while (!$iterator->finished && $iterator->peek->{other_uri}->value eq $other_uri) {
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
    # value() on each result takes the literal and extracts the value from its xsd:datatype and any quotes
    my $best_score;
    my $best_type = $first->{link_type}->value;
    $best_score = $first->{score}->value if exists $first->{score};
    my $our_uri = $first->{ens_uri}->value;
    my $our_label = $first->{ens_label}->value;
    my $other_label = $first->{other_label}->value;
    push @winners,[$our_uri,$our_label,$other_uri,$other_label]; # Sorted results means top one is always a winner
    $self->dump_decision_table($first,1) if $self->debug_fh;
    $selected_items++;
    # Find any joint winners
    while (my $candidate = shift @candidates) {
      last if (
           $candidate->{link_type}->value ne $best_type # types must be the same to join the bandwagon
        || ( exists $candidate->{score} && $candidate->{score}->value < $best_score) # scores must be equal
      );
      
      push @winners,[$our_uri,$our_label,$candidate->{other_uri}->value,$candidate->{other_label}->value];
      $self->dump_decision_table($candidate,1) if $self->debug_fh;
      $selected_items++;
    }
    if ($self->debug_fh) {
      foreach my $leftover (@candidates) { 
        $self->dump_decision_table($leftover,0);
      }
    }
    # And reset for the next ID in the buffer.
    @candidates = ();
  }
  
  printf "Selected %s best xrefs from %s overlaps, checksums and alignment matches\n",$selected_items,$original_total;
  return \@winners;
}

# Custom bulk insert-builder for best alignments, and loads them into $graph
# Expects a list like [$uri,$label,$target_uri,$target_label,...]
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
      $triples .= sprintf qq(<%s> term:refers-to <%s> .\n <%s> term:refers-to <%s> .\n <%s> dc:identifier "%s" .\n <%s> dc:identifier "%s" .\n), 
                    $hit->[0],
                    $hit->[2],
                    $hit->[2],
                    $hit->[0],
                    $hit->[0],
                    $hit->[1],
                    $hit->[2],
                    $hit->[3]; # Ensembl points to Refseq and the converse
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

# Watch out, the result buffer can be super-huge in memory
sub calculate_stats {
  my $self = shift;
  my $graph = shift;
  $graph = $self->triplestore->graph_url unless $graph;
  # Select only most generic source types, to allow RefSeq and other multi-type sources to group together
  my $sparql_stats = "
    SELECT DISTINCT ?source_a ?source_b (COUNT(?source_b) as ?count) FROM <$graph> WHERE {
          ?entity term:generic-source ?source_a .
          ?entity term:refers-to ?xref .
          ?xref term:refers-to ?other .
          ?other term:generic-source ?source_b .
    } 
    GROUP BY ?source_a ?source_b 
    ORDER BY DESC(?count)";

  my $results = $self->triplestore->query($self->prefixes.$sparql_stats);
  return [$results->get_all];
}

# Print a tabular form of the results of calculate_stats()
sub pretty_print_stats {
  my $self = shift;
  my $stats = shift;

  printf "%20s %20s %s\n",'From','To','Count';
  while ( my $stat = shift @$stats) {
    if (defined $stat && defined $stat->{source_a} && $stat->{source_b} && $stat->{count}) {
      printf "%20s %20s %d\n",$stat->{source_a}->value,$stat->{source_b}->value,$stat->{count}->value;
    } else {
      use Data::Dumper;
      warn "Issue printing stats: ".Dumper($stat);
    }
  }
}

# Use property path functions of SPARQL to get all entities connected, irrespective of number of hops
# SPARQL implementations Automatically deal with cyclic relations
sub extract_transitive_xrefs_for_id {
  my $self = shift;
  my $id = shift;
  my $graph_url = $self->triplestore->graph_url;
  my $condensed_graph = $self->condensed_graph_name($graph_url);

  my $sparql = sprintf qq(SELECT DISTINCT ?uri ?xref_source ?xref_label FROM <%s> {
    ?o dc:identifier "%s" .
    ?o term:refers-to+ ?uri .
    ?uri dc:identifier ?xref_label .
    ?uri dcterms:source ?xref_source
    }), $condensed_graph,$id;

  my $iterator = $self->triplestore->query($self->prefixes.$sparql);
  my @results = map { 
    { 
      uri => $_->{uri}->value,
      xref_label => $_->{xref_label}->value,
      xref_source => $_->{xref_source}->value
     }
    } $iterator->get_all;
  return \@results;
}


# Given a single URL, get all the xrefs directly attached to it from the default graph.
sub get_related_xrefs {
  my $self = shift;
  my $url = shift;

  my $graph_url = $self->triplestore->graph_url;

  my $sparql = sprintf qq(SELECT ?uri ?source ?id ?type ?score ?display_label ?description FROM <%s> WHERE {
      <%s> term:refers-to ?xref .
      ?xref rdf:type ?type .
      ?xref term:refers-to ?uri .
      ?uri dcterms:source ?source .
      ?uri dc:identifier ?id .
      OPTIONAL { ?uri term:display_label ?display_label }
      OPTIONAL { ?uri dc:description ?description }
      OPTIONAL { ?xref term:score ?score }
    }),$graph_url,$url;
  my $iterator = $self->triplestore->query($self->prefixes.$sparql);
  my @results = map { 
    { 
      uri => $_->{uri}->value,
      source => $_->{source}->value,
      id => $_->{id}->value,
      type => $_->{type}->value,
      score => (exists $_->{score}) ? $_->{score}->value : undef,
      display_label => (exists $_->{display_label}) ? $_->{display_label}->value : undef,
      description => (exists $_->{description}) ? $_->{description}->value : undef
     }
    } $iterator->get_all;
  return \@results;
}

# Get annotation information for a single URI
sub get_detail_of_uri {
  my $self = shift;
  my $url = shift;

  my $graph_url = $self->triplestore->graph_url;
  my $sparql = sprintf qq(
    SELECT ?id ?source ?description ?display_label FROM <%s> WHERE {
      <%s> dcterms:source ?source .
      <%s> dc:identifier ?id .
      OPTIONAL { <%s> term:description ?description } .
      OPTIONAL { <%s> term:display_label ?display_label }
    }
  ), $graph_url, $url, $url, $url, $url;
  my $iterator = $self->triplestore->query($self->prefixes.$sparql);
  my @results = map { 
    { 
      source => $_->{source}->value,
      id => $_->{id}->value,
      display_label => (exists $_->{display_label}) ? $_->{display_label}->value : undef,
      description => (exists $_->{description}) ? $_->{description}->value : undef
    }
    } $iterator->get_all;
  return \@results;
}

# Used for in-filling scores for alignments when we are not prescient enough to have fetched it in a previous query
# if a--90%->b and b--85%->a , it is convenient to be able to retrieve the b->a case when we're seeing a->b
sub get_target_identity {
  my $self = shift;
  my $e_uri = shift;
  my $o_uri = shift;
  my $graph_url = $self->triplestore->graph_url;
  my $sparql = sprintf qq(
  SELECT ?score FROM <%s> WHERE {
    <%s> term:refers-to ?xref .
    ?xref term:score ?score .
    ?xref rdf:type term:Alignment .
    ?xref term:refers-to <%s> .
  }
  ), $graph_url, $o_uri, $e_uri;
  my $iterator = $self->triplestore->query($self->prefixes.$sparql);
  if (!defined $iterator) {
    Bio::EnsEMBL::Mongoose::DBException->throw("No result returned for finding alignment score of $o_uri to $e_uri");    
  }
  my $hit = $iterator->next;
  return $hit->{score}->value;
}


# Reactome data is of type "annotation", and cannot be transitively linked. It is also inbound, and unreachable by
# the default approach of outward search. For special cases we can include selected inbound xrefs
# Specify the intermediary source (for Reactome this is Uniprot), the source we want xrefs from (Reactome)
# This information is required to ensure the query resolves as early as possible

# Relies on trusting direct xrefs from connecting_source to e_uri
sub get_weakly_connected_xrefs {
  my $self = shift;
  my $e_id = shift; # ENSP ID
  my $e_source = shift; # ensID source, e.g. http://rdf.ebi.ac.uk/resource/ensembl.protein/
  my $connecting_source = shift; # e.g. http://purl.uniprot.org/uniprot/
  my $source = shift; # The URI for the external source we want to connect to. e.g. http://identifiers.org/reactome/

  my $graph_url = $self->triplestore->graph_url;
  my $sparql = sprintf qq(
    SELECT ?id ?display_label ?description FROM <%s> WHERE {
      ?e dc:identifier "%s" .
      ?e term:generic-source <%s> .
      ?xref term:refers-to ?e .
      ?primary_xref term:refers-to ?xref .
      ?primary_xref term:generic-source <%s> .
      ?xref2 term:refers-to ?primary_xref .
      ?secondary_xref term:refers-to ?xref2 .
      ?secondary_xref term:generic-source <%s> ;
                      dc:identifier ?id ;
                      term:display_label ?display_label ;
                      term:description ?description .
    }
  ),$graph_url,$e_id,$e_source,$connecting_source,$source;

  my $iterator = $self->triplestore->query($self->prefixes.$sparql);
  my @results = map { 
    {
      id => $_->{id}->value,
      display_label => $_->{display_label}->value,
      description => $_->{description}->value
    } 
    } $iterator->get_all;
  return \@results;
}

# Find any xrefs from a given generic-type source URI to the target Ensembl ID.
# This is for sources which have no transitive connection to the Ensembl ID
# and cannot be found by outbound connection. Therefore get them by their inbound connection
# This is necessary for sources like ArrayExpress
sub get_directly_connected_xrefs {
  my $self = shift;
  my $e_id = shift; # ENS ID
  my $e_source = shift; # http://rdf.ebi.ac.uk/resource/ensembl.protein/ or similar
  my $connected_source = shift;

  my $graph_url = $self->triplestore->graph_url;
  my $sparql = sprintf qq(
    SELECT ?id ?display_label ?description FROM <%s> WHERE {
      ?e dc:identifier "%s";
         term:generic-source <%s> .
      ?xref term:refers-to ?e ;
            rdf:type ?type .
      ?other term:refers-to ?xref ;
             term:generic-source <%s> ;
             dc:identifier ?id ;
             term:display_label ?display_label;
             term:description ?description .
    }
  ),$graph_url,$e_id, $e_source, $connected_source;
  my $iterator = $self->triplestore->query($self->prefixes.$sparql);
  my @results = map {
    {
      id => $_->{id}->value,
      display_label => $_->{display_label}->value,
      description => $_->{description}->value 
    }
  } $iterator->get_all;
  return \@results;
}

# Set or generate and return the "transitive graph name" that is required for querying it
sub condensed_graph_name {
  my $self = shift;
  my $condensed_graph = shift;
  $condensed_graph =~ s/xref$//;
  $condensed_graph .= 'condensed';
  return $condensed_graph;
}

# Print out all the information used to assign RefSeq proteins to Ensembl translations.
# The winner is marked x, and any transcript evidence considered is indicated with a number
# 1 = transcript pair agrees
# 0 = no transcript pairing is of use here
# -1 = transcript pairings indicate another protein pair would be a better choice
sub dump_decision_table {
  my $self = shift;
  my $result = shift;
  my $winner = shift;
  my $fh = $self->debug_fh;
  my $type = $result->{link_type}->value;
  $type =~ s|http://rdf.ebi.ac.uk/terms/ensembl/||;
  no warnings 'uninitialized';
  printf $fh "%s\t%s\t%s\t%.2f\t%s\t%s\t%s\n",
    $result->{other_label}->value, 
    $result->{other_uri}->value,
    $type,
    (exists $result->{score}) ? $result->{score}->value : undef, 
    $result->{ens_label}->value, 
    $result->{ens_uri}->value,
    ($winner) ? 'x': '' ;
}


__PACKAGE__->meta->make_immutable;
1;
