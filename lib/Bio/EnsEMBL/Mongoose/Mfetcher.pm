package Bio::EnsEMBL::Mongoose::Mfetcher;

use Moose;

use Bio::EnsEMBL::Mongoose::Serializer::FASTA;
use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::Taxonomizer;

use Bio::EnsEMBL::Mongoose::SearchEngineException

has handle => (
    isa => 'Maybe[Ref]',
    is => 'ro',
    lazy => 1,
    default => sub{},
);

has fasta_writer => (
    isa => 'Bio::EnsEMBL::Mongoose::Serializer::FASTA',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $handle = $self->handle;
        if ($handle) {
            return Bio::EnsEMBL::Mongoose::Serializer::FASTA->new(handle => $handle);
        }
        return Bio::EnsEMBL::Mongoose::Serializer::FASTA->new();
    }
);

has query_params => (
    isa => 'Bio::EnsEMBL::Mongoose::Persistence::QueryParameters',
    is => 'rw',
);

has storage_engine => (
    isa => 'Bio::EnsEMBL::Mongoose::Persistence::LucyQuery',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        return Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config_file => $self->storage_engine_conf,buffer_size => 5000);        
    }
);

has storage_engine_conf => (
    isa => 'Str',
    is => 'ro',
    required => 1,
);

has taxonomizer => (
    isa => 'Bio::EnsEMBL::Mongoose::Taxonomizer',
    is => 'ro',
    lazy => 1,
    default => sub {
        return Bio::EnsEMBL::Mongoose::Taxonomizer->new;
    }
);

with 'MooseX::Log::Log4perl';

my $counter = 0;

sub get_sequence {
    my $self = shift;
    $self->storage_engine->query_parameters($self->query_params);
    $self->storage_engine->query();

    while (my $result = $self->storage_engine->next_result) {
        my $record = $self->storage_engine->convert_result_to_record($result);
        $self->fasta_writer->print_record($record);
        $counter++;
        if ($counter % 10000 == 0) {
            $self->log->info("Dumped $counter records");
        }
    }
}

sub get_sequence_by_species_name {
    my $self = shift;
    if ($self->query_params->species_name) { $self->convert_name_to_taxon }
    $self->get_sequence;
}

sub get_sequence_including_descendants {
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
    $self->get_sequence;
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

1;