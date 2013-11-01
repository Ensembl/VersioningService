package Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Moose;

use Lucy::Search::IndexSearcher;
use Lucy::Search::QueryParser;
use Search::Query;
use Search::Query::Parser;
use Search::Query::Dialect::Lucy;

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;

use Data::Dump::Color qw/dump/;
use Sereal::Decoder qw/decode_sereal/;

has search_engine => (
    isa => 'Lucy::Search::IndexSearcher',
    is => 'ro',
    required => 1,
    default => sub {
        my $self = shift;
        return Lucy::Search::IndexSearcher->new(
            index => $self->config->{index_location},
        );
    }
); 

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
        
    }
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

has buffer_size => (
    isa => 'Int',
    is => 'rw',
    default => 1000,
);

with 'Bio::EnsEMBL::Mongoose::Persistence::Query';
with 'MooseX::Log::Log4perl';

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
    $self->log->debug('Built query: '.$query);
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
    $self->log->debug('Query: '.$self->query_string);
}

sub next_result {
    my $self = shift;
    if ($self->cursor % $self->buffer_size == 0) {
        $self->log->debug('Iterator position: '.$self->cursor);
        $self->log->debug('Result buffer dry, fetch more');
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
    my $blob = $result->{'blob'};
    #print $result->{'blob'}."\n";
    my $record = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder::decompress_sereal($self,$blob);
    return $record;
}

sub get_all_records {
    my $self = shift;
    my @records;
    while (my $result = $self->next_result) {
        push @records,$self->convert_result_to_record($result);
    }
    return \@records;
}

__PACKAGE__->meta->make_immutable;

1;
