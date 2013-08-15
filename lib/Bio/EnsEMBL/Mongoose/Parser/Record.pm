package Bio::EnsEMBL::Mongoose::Parser::Record;
use Moose;
use MooseX::Storage;

with Storage('format' => 'JSON', 'io' => 'File');

has id => (
    isa => 'Str',
    is => 'rw',
    required => 0,
);

has sequence => (
    isa => 'Str',
    is => 'rw',
);

has sequence_length => (
    isa => 'Int',
    is => 'rw',
);

has region => (
    isa => 'Str',
    is => 'rw',
);

has primary_accession => (
    isa => 'Str',
    is => 'rw',
);

has gene_name => (
    isa => 'Str',
    is => 'rw',
);

has accessions => (
    isa => 'ArrayRef[Str]',
    is => 'rw',
    traits => ['Array'],
);

has display_label => (
    isa => 'Str',
    is => 'rw',
);

has description => (
    isa => 'Str',
    is => 'rw',
);

has checksum => (
    isa => 'Str',
    is => 'rw',
);

has version => (
    isa => 'Int',
    is => 'rw',
);

has taxon_id => (
    isa => 'Int',
    is => 'rw',
);

has schema_version => (
    isa => 'Int',
    is => 'rw',
);

has evidence_level => (
    isa => 'Int',
    is => 'rw',
    default => 5,
);

has suspicion => (
    isa => 'Str',
    is => 'rw',
);

__PACKAGE__->meta->make_immutable;

1;