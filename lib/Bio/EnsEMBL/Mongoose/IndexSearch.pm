package Bio::EnsEMBL::Mongoose::IndexSearch;

use Moose;
use Moose::Util::TypeConstraints;
use Method::Signatures;

use Bio::EnsEMBL::Mongoose::Serializer::FASTA;
use Bio::EnsEMBL::Mongoose::Serializer::JSON;
use Bio::EnsEMBL::Mongoose::Serializer::ID;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::Taxonomizer;
use Bio::EnsEMBL::Versioning::Broker;

use IO::File;
use Bio::EnsEMBL::Mongoose::SearchEngineException;
use Bio::EnsEMBL::Mongoose::IOException;

has handle => (
    isa => 'Maybe[Ref]',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        # no file handle, let the handle point to a copy of STDOUT instead
        my $handle;
        $self->log->debug("Making handle");
        open $handle, ">&STDOUT";
        return $handle;
    },
);

sub DEMOLISH {
    my $self = shift;
    close $self->handle;
    $self->log->debug("File handle released");
}

enum 'Formats', [qw(FASTA JSON ID RDF EnsemblRDF)];

has output_format => (
    isa => 'Formats',
    is => 'rw',
    default => 'FASTA',
);

has writer => (
    isa => 'Object',
    is => 'rw',
    lazy => 1,
    builder => '_select_writer',
);

sub _select_writer {
    my $self = shift;
    my $format = $self->output_format;
    my $writer = "Bio::EnsEMBL::Mongoose::Serializer::$format";
    return $writer->new(handle => $self->handle);
}

# Contains information about the index Lucy will use, either by file or hash.
has storage_engine_conf_file => ( isa => 'Str', is => 'rw', predicate => 'using_conf_file');
has storage_engine_conf => (isa => 'HashRef', is => 'rw');

has storage_engine => (
    isa => 'Bio::EnsEMBL::Mongoose::Persistence::LucyQuery',
    is => 'ro',
    lazy => 1,
    builder => '_init_storage',
);

sub _init_storage {
    my $self = shift;
    my $store;
    if ($self->using_conf_file) {
        $store = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config_file => $self->storage_engine_conf_file);
    } else {
        $store = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => $self->storage_engine_conf);
    }
    return $store;
}

has species => (isa => 'Str', is => 'rw',default => 'human');
has source => (isa => 'Str', is => 'rw',default => 'UniProtSwissProt');

has query_params => (
    isa => 'Object',
    is => 'rw',
    builder => '_populate_query_object',
    lazy => 1,
);

sub _populate_query_object {
    my $self = shift;
    my $taxon = $self->taxonomizer->fetch_taxon_id_by_name($self->species);
    my $query = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
        taxons => [$taxon],
        format => $self->output_format,
    );
    return $query;
}

has versioning_service => (
    isa => 'Bio::EnsEMBL::Versioning::Broker',
    is => 'ro',
    lazy => 1,
    predicate => 'versioning_service_ready',
    builder => '_awaken_giant',
);

sub _awaken_giant {
    my $self = shift;
    my $broker = Bio::EnsEMBL::Versioning::Broker->new();
    $broker->init_broker;
    return $broker;
}

has taxonomizer => (
    isa => 'Bio::EnsEMBL::Mongoose::Taxonomizer',
    is => 'ro',
    lazy => 1,
    default => sub {
        return Bio::EnsEMBL::Mongoose::Taxonomizer->new;
    }
);

has refer_to_blacklist => (
    isa => 'Bool',
    is => 'rw',
    traits => ['Bool'],
    default => 0,
    handles => {
        use_blacklist => 'set',
        ignore_blacklist => 'unset',
    }
);

has blacklist => (
    isa => 'HashRef[Str]',
    is => 'rw',
    lazy => 1,
    builder => '_build_blacklist',
    traits => ['Hash'],
    handles => {
        clear_blacklist => 'clear',
    }
);

has blacklist_source => (
    isa => 'Str',
    is => 'rw',
    lazy => 1,
    default => '',
);

with 'MooseX::Log::Log4perl';


sub _build_blacklist {
    my $self = shift;
    my $fh = IO::File->new($self->blacklist_source) 
        || Bio::EnsEMBL::Mongoose::IOException->throw( message => "Couldn't open supplied blacklist ".$self->blacklist_source);
    while (my $banned = <$fh>) {
        chomp($banned);
        $self->blacklist->set($banned => 1);
    }
    $self->use_blacklist;
}

my $counter = 0;
sub get_records {
    my $self = shift;
    $self->storage_engine->query_parameters($self->query_params);
    $self->storage_engine->query();
    my $source = $self->source();
    while (my $result = $self->storage_engine->next_result) {
        my $record = $self->storage_engine->convert_result_to_record($result);
        # Filter record against a possible blacklist of unwanted accessions. Quite possibly slow
        if ($self->refer_to_blacklist) {
            my @accessions = @{$record->accessions} if $record->accessions;
            foreach my $accession (@accessions) {
                if ($self->blacklist->exists($accession)) {next; $self->log->debug('Skipping blacklisted id: '.$accession)}
            }
        }
        $self->writer->print_record($record, $source);
        $counter++;
        if ($counter % 10000 == 0) {
            $self->log->info("Dumped $counter records");
        }
    }
}

sub get_records_by_species_name {
    my $self = shift;
    if ($self->query_params->species_name) { $self->convert_name_to_taxon }
    $self->get_records;
}

sub get_records_including_descendants {
    my $self = shift;
    if ($self->query_params->species_name) { $self->convert_name_to_taxon }
    my $taxon_list = $self->query_params->taxons;
    $self->log->info('Starter taxons: '.join(',',@$taxon_list));
    my @final_list;
    foreach my $taxon (@$taxon_list) {
        my $list = $self->taxonomizer->fetch_nested_taxons($taxon);
        push @final_list,@$list;
    }
    $self->log->debug('Querying multiple taxons: '.join(',',@final_list));
    $self->query_params->taxons(\@final_list);
    $self->get_records;
}

sub convert_name_to_taxon {
    my $self = shift;
    my $name = $self->query_params->species_name;
    my $taxon = $self->taxonomizer->fetch_taxon_id_by_name($name);
    unless ($taxon) {
        Bio::EnsEMBL::Mongoose::SearchEngineException->throw(
            message => 'Supplied species name '.$name.' did not translate to a taxon, check spelling versus NCBI taxonomy.',
        );
    }
    $self->query_params->taxons([$taxon]);
}

method work_with_index ( Str :$source, Str :$version? ) {
  # unless ($self->versioning_service_ready() ) { Bio::EnsEMBL::Mongoose::SearchEngineException->throw('Versioning service not initialised.') }
  my $path = $self->versioning_service->get_index_by_name_and_version($source,$version);
  $self->log->debug('Switching to index: '.$path);
  $self->storage_engine_conf({ index_location => $path, source => $source, version => $version});
  $self->storage_engine();
}

__PACKAGE__->meta->make_immutable;

1;