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

=head1 DESCRIPTION

IndexSearch provides a targetted interface to Lucy indexes for extracting records and dumping them.
It is intended to replicate some functionality that was previously provided by mfetch and pfetch utilities.

It needs access to the Versioning Service database, and the corresponding file system to access the data.
Tne serialisation format as specified at initialisation is then used to dump subsets of records. Valid 
formats include FASTA, JSON, and (Ensembl-specific) RDF. The resulting records, usually limited to a 
single species are then dumped in that format.

Note that to use the RDF serialiser, more configuration is required.

=head1 SYNOPSIS

# Unless a filehandle or path is specified, the output will go to STDOUT
my $search = Bio::EnsEMBL::Mongoose::IndexSearch->new(
  output_format => 'FASTA', 
  storage_engine_conf_file => $ENV{MONGOOSE}.'./conf/manager.conf'
);

my $source_list = $mfetcher->versioning_service->get_active_sources;

my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    taxons => [9606]
);

foreach my $source (@$source_list) {
  $search->work_with_index(source => $source->name);
  $search->query_params($params);
  $search->get_records();
}
# See also Bio::EnsEMBL::Mongoose::Persistence::QueryParameters for other kinds of filtering

=cut

package Bio::EnsEMBL::Mongoose::IndexSearch;

use Moose;
use Moose::Util::TypeConstraints;
use Method::Signatures;

use Bio::EnsEMBL::Mongoose::Serializer::FASTA;
use Bio::EnsEMBL::Mongoose::Serializer::JSON;
use Bio::EnsEMBL::Mongoose::Serializer::ID;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;

# In future this module should not be tightly tied to Apache Lucy, but allow
# any document store to queried in this fashion, at least within the Lucene family.
use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::Taxonomizer;
use Bio::EnsEMBL::Versioning::Broker;

use IO::File;
use Bio::EnsEMBL::Mongoose::SearchEngineException;
use Bio::EnsEMBL::Mongoose::IOException;

extends 'Bio::EnsEMBL::Mongoose::IndexReader';

has handle => (
    isa => 'Maybe[Ref]',
    is => 'rw',
    lazy => 1,
    default => sub {
        my $self = shift;
        # no file handle, let the handle point to a copy of STDOUT instead
        my $handle;
        $self->log->trace("Making handle");
        open $handle, ">&STDOUT";
        return $handle;
    },
    predicate => 'straight_to_file'
);

has other_handle => (
    isa => 'Ref',
    is => 'rw',
); # Exists for when output must be split into different places

sub DEMOLISH {
    my $self = shift;
    close $self->handle;
    $self->log->trace("File handle released");
}

enum 'Formats', [qw(FASTA JSON ID RDF)];

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

# Needed for writers that need additional configuration (eg. RDF writer)
has writer_conf => (
    isa => 'HashRef', is => 'rw', lazy => 1, default => sub { my $self = shift; $self->storage_engine_conf }
);

sub _select_writer {
    my $self = shift;
    my $format = $self->output_format;
    my $writer = "Bio::EnsEMBL::Mongoose::Serializer::$format";
    if ($self->other_handle) {
        return $writer->new(handle => $self->handle, config => $self->writer_conf, gene_model_handle => $self->other_handle);
    } else {
        return $writer->new(handle => $self->handle, config => $self->writer_conf);
    }
}

# To indicate whether to use Uniprot Web service to get additional data
has isoforms => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
    traits => ['Bool'],
    handles => {
        include_isoforms => 'set',
        ignore_isoforms => 'unset'
    }
);

# allow custom filtering subroutines to prevent the exporting of unwanted datatypes.
# Sample:
# sub { my $record = shift; return 1 if $record =~ /NiceId/}
# This would be faster if implemented directly into the queries, but Lucy needs custom extension for wildcard matching
has filter => (
    isa => 'CodeRef',
    is => 'rw',
    traits => ['Code'],
    predicate => 'custom_filter',
    handles => {
        include_record => 'execute'
    },
    clearer => 'disable_filter'
);

with 'MooseX::Log::Log4perl','Bio::EnsEMBL::Versioning::Pipeline::Downloader::RESTClient';

my $counter = 0;
sub get_records {
    my $self = shift;
    my $source = $self->source();

    $self->storage_engine->query_parameters($self->query_params);
    $self->storage_engine->query();
    
    while (my $record = $self->next_record) {
        next unless ($self->custom_filter && $self->include_record($record)) || !$self->custom_filter;
        $self->writer->print_record($record, $source);
        if ($self->isoforms) {
            $self->log->debug("Adding isoforms from Uniprot website");
            $self->add_isoforms($record);
        }
        $counter++;
        if ($counter % 10000 == 0) {
            $self->log->info("Dumped $counter records");
        }
    }
}
sub get_slimline_records {
    my $self = shift;
    my $fh = shift;
    my $source = $self->source();

    $self->storage_engine->query_parameters($self->query_params);
    $self->storage_engine->query();
    
    while (my $record = $self->next_record) {
        next unless ($self->custom_filter && $self->include_record($record)) || !$self->custom_filter;
        $self->writer->print_slimline_record($record, $source, $fh);
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

sub add_isoforms { 
    my $self = shift;
    my $record = shift;
    my $isoforms = $record->isoforms;
    my $fh = $self->writer->handle;
    foreach my $iso (@$isoforms) {
        my $response = call( -host => 'www.uniprot.org',
              -path => 'uniprot/'.$iso.'.fasta',
        );
        print $fh $response;
    }
}



__PACKAGE__->meta->make_immutable;

1;
