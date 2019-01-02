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

=head1 DESCRIPTION

A Apache Lucy wrapper to allow querying of indexes. Results are presented via
an iterator, and are buffered to assist in rapid dumping of data.

=cut

package Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Moose;

use Lucy::Search::IndexSearcher;
use Lucy::Search::PolySearcher;
use Lucy::Search::QueryParser;
use Search::Query;
use Search::Query::Parser;
use Search::Query::Dialect::Lucy;

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;

use Bio::EnsEMBL::Mongoose::SearchEngineException;

use Data::Dumper;
use Sereal::Decoder qw/decode_sereal/;

has search_engine => (
    isa => 'Lucy::Search::Searcher',
    is => 'ro',
    required => 1,
    lazy => 1,
    builder => '_configure_search_engine'
);

sub _configure_search_engine {
  my $self = shift;
  $self->log->debug(Dumper $self->config);
  my $indexes = $self->config->{index_location};
  if (ref $indexes eq 'ARRAY') {

    if (scalar @$indexes > 1) {
      my @searchers;
      foreach my $index (@$indexes) {
        if (!defined $index) {
          Bio::EnsEMBL::SearchEngineException->throw('Index path not defined. Disaster! Received '.join ',',@$indexes);
        }
        push @searchers,Lucy::Search::IndexSearcher->new(index => $index); 
      }
      return Lucy::Search::PolySearcher->new(
        searchers => \@searchers,
        schema => $searchers[0]->get_schema
      );
    } elsif ( scalar @$indexes == 1 ) {
      # PolySearcher is less efficient than a single one, so remove it for single index cases
      return Lucy::Search::IndexSearcher->new( index => $indexes->[0] );
    } else {
      Bio::EnsEMBL::Mongoose::SearchEngineException->throw('Empty array of index paths, cannot query no indexes');
    }
    
  } elsif (-d $indexes) {
    # When given a single argument it should be a path to single index
    return Lucy::Search::IndexSearcher->new( index => $indexes );
  } else {
    Bio::EnsEMBL::Mongoose::SearchEngineException->throw('No index location provided for search engine');
  }
}

has query_parser => (
    isa => 'Search::Query::Parser',
    is => 'ro',
    required => 1,
    lazy => 1,
    default => sub {
        my $self = shift;
        return Search::Query->parser( 
            dialect => 'Lucy', 
            fields  => $self->search_engine->get_schema()->all_fields,
        );
    }
);

has result_set => (
    isa => 'Lucy::Search::Hits',
    is => 'rw',
    lazy => 1,
    default => sub {
        
    },
    predicate => 'mid_query'
);

has parsed_query => (
    isa => 'Object',
    is => 'rw',
);

has cursor => (
    traits => ['Counter'],
    isa => 'Int',
    is => 'rw',
    default => 0,
    handles => {
        move_cursor => 'inc',
    }
);
# Consider setting buffer size from config?
has buffer_size => (
    isa => 'Int',
    is => 'rw',
    default => 1000,
);

# Used to inform the writer where this data came from, e.g. for URI generation or metadata.
has source => (is => 'rw',isa => 'Str');
has version => (is => 'rw', isa => 'Maybe[Str]');

with 'Bio::EnsEMBL::Mongoose::Persistence::Query','MooseX::Log::Log4perl';

# Search::Query::Dialect::Lucy translates the following syntax into useful queries
# Beware the shell, escape all of them outside of Perl
#
# Binary operators as symbols or words. AND is more or less implicit, but beware precedence
#   accessions:(name | name2 | name3 OR name4) & (evidence_level:5)
#
# Range query
#   evidence_level:4..5
#
# Wild cards
#   accessions:AAAA*

# See also https://metacpan.org/source/KARMAN/Search-Query-Dialect-Lucy-0.10/t/01-parser.t


sub build_query {
    my $self = shift;
    my $query;
    my $query_params = $self->query_parameters;
    if ($query_params) {
        # Add constraints
        if ($query_params->count_ids > 0) {
            my @accessions = $query_params->all_ids;
            $query = $query_params->id_type.':('.join('|',@accessions).')';
        }
        if ($query_params->evidence_level) {
            $query .= ' evidence_level:'.$query_params->evidence_level;
        }
        if ($query_params->has_taxons) {
            $query .= ' taxon_id:('.join(' | ',$query_params->constrain_to_taxons).')';
        }
        if ($query_params->checksum) {
            $query .= ' checksum:'.$query_params->checksum;
        }
        unless (length($query) > 0) {
            Bio::EnsEMBL::Mongoose::SearchEngineException->throw(
                message => 'Lucy requires one of accession, evidence level or taxon id to make a query',
            );
        }
    } else {
        Bio::EnsEMBL::Mongoose::SearchEngineException->throw(
            message => 'Lucy requires at least some query parameters',
        );
    }
    $self->query_string($query);
}

# query() also works with an argument which circumvents the query_builder

sub query {
    my $self = shift;
    my $query = shift;
    if (!$query) {
        $self->build_query;
    } else {
        $self->query_string($query);
    }
    my $search = $self->query_parser->parse($self->query_string)->as_lucy_query;
    $self->parsed_query($search);
    $self->cursor(0);
    $self->result_set($self->search_engine->hits(
            query => $search,
            num_wanted => $self->buffer_size, 
            offset => $self->cursor)
        );
    $self->log->debug('Query: '.$self->query_string);
}

sub next_result {
    my $self = shift;
    if ($self->cursor % $self->buffer_size == 0) {
        $self->log->trace('Iterator position: '.$self->cursor);
        $self->log->trace('Result buffer dry, fetch more');
        $self->result_set($self->search_engine->hits(
            query => $self->parsed_query,
            num_wanted => $self->buffer_size, 
            offset => $self->cursor)
        );
    }
    $self->move_cursor;
    return $self->result_set->next;
};

sub convert_result_to_record {
    my $self = shift;
    my $result = shift;
    my $blob = $result->{blob};
    #print $result->{'blob'}."\n";
    my $record = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder::decompress_sereal($self,$blob);
    return $record;
}

# Only use in small subsets of data. This one swallows memory.
sub get_all_records {
    my $self = shift;
    my @records;
    while (my $result = $self->next_result) {
        push @records,$self->convert_result_to_record($result);
    }
    return \@records;
}

# Build term query
sub build_term_query {
  my $self = shift;
  my ($args) = @_;

  my $term_query = Lucy::Search::TermQuery->new(
    field => $args->{field},
    term  => $args->{term},
  );
  return $term_query;
}


## Build range query
sub build_range_query {
  my $self = shift;
  my ($args) = @_;
  my $range_query;

  if(exists $args->{include_upper} && exists $args->{include_lower}){
    $range_query = Lucy::Search::RangeQuery->new(
      field         => $args->{field},
      lower_term    => $args->{lower_term},
      upper_term    => $args->{upper_term},
      include_upper => $args->{include_upper},
      include_lower => $args->{include_lower},
   );
  }elsif(exists $args->{include_upper}){
    $range_query = Lucy::Search::RangeQuery->new(
      field         => $args->{field},
      upper_term    => $args->{upper_term},
      include_upper => $args->{include_upper},
   );
  }elsif(exists $args->{include_lower}){
    $range_query = Lucy::Search::RangeQuery->new(
      field         => $args->{field},
      lower_term    => $args->{lower_term},
      include_lower => $args->{include_lower},
   );
  }

  return $range_query;
}
sub fetch_region_overlaps{
  my ($self, $taxon_id, $chromosome, $strand, $start, $end) = @_;

  my $term_query_species = $self->build_term_query({field => "taxon_id", term => $taxon_id});
  my $term_query_chromosome = $self->build_term_query({field => "chromosome", term => $chromosome});
  my $term_query_strand = $self->build_term_query({field => "strand", term => $strand});

  my $taxon_and_chr_strand_query = Lucy::Search::ANDQuery->new(
    children => [ $term_query_species, $term_query_chromosome, $term_query_strand ],
  );

  #transcript_start_padded >= start and transcript_start_padded <=end
  my $range_query1 = $self->build_range_query({field => "transcript_start_padded", lower_term => $start, upper_term=>$end, include_lower => 1, include_upper => 1});

   #transcript_end_padded >= start and transcript_end_padded <=end
  my $range_query2 = $self->build_range_query({field => "transcript_end_padded", lower_term => $start, upper_term=>$end, include_lower => 1, include_upper => 1});

  #lower_term - Lower delimiter. If not supplied, all values less than upper_term will pass.
  my $range_query3 = $self->build_range_query({field => "transcript_start_padded", upper_term=>$start, include_upper => 1});

  #upper_term - Upper delimiter. If not supplied, all values greater than lower_term will pass.
  my $range_query4 = $self->build_range_query({field => "transcript_end_padded", lower_term=>$end, include_lower => 1});

  #(txStart <= 10000 AND txEnd >= 90500))
  my $and_query_range = Lucy::Search::ANDQuery->new(
    children => [ $range_query3, $range_query4 ],
  );

  #== ((txStart BETWEEN 10000 AND 90500) OR (txEnd BETWEEN 10000 AND 90500) OR (txStart <= 10000 AND txEnd >= 90500))
  my $or_query = Lucy::Search::ORQuery->new(
    children => [ $range_query1, $range_query2, $and_query_range ],
  );

  my $final_query = Lucy::Search::ANDQuery->new(
    children => [ $taxon_and_chr_strand_query, $or_query ],
  );

  my $hits = $self->search_engine->hits(
        query      => $final_query,
        num_wanted => 1000000,
  );

  my $hit_count = $hits->total_hits;  # get the hit count here
  my @results;
  while ( my $hit = $hits->next ) {
    my $record = $self->convert_result_to_record($hit);
    push @results, $record;
  }

  return \@results;
}

__PACKAGE__->meta->make_immutable;

1;
