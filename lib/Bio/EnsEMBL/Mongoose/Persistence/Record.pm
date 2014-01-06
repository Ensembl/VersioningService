package Bio::EnsEMBL::Mongoose::Persistence::Record;
use Moose;

use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

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

has gene_name => (
    isa => 'Str',
    is => 'rw',
);

has full_name => (
    isa => 'Str',
    is => 'rw',
);

has accessions => (
    isa => 'ArrayRef[Str]',
    is => 'rw',
    traits => ['Array'],
);

has synonyms => (
    isa => 'ArrayRef[Str]',
    is => 'rw',
    traits => ['Array'],
    handles => {
        add_synonym => 'push'
    }
);

has xref => (
    isa => 'ArrayRef[Bio::EnsEMBL::Mongoose::Persistence::RecordXref]',
    is => 'rw',
    traits => ['Array'],
    default => sub {[]},
    handles => {
        add_xref => 'push',
        remove_xref => 'pop',
        grep_xrefs => 'grep',
        map_xrefs => 'map',
        count_xrefs => 'count',
    }
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
);
# 1 = Protein level
# 2 = Transcript level
# 3 = Support by homology
# 4 = Predicted
# 5 = Uncertain

has suspicion => (
    isa => 'Str',
    is => 'rw',
);

sub TO_JSON {
    return {%{shift()}};
}

sub primary_accession {
    my $self = shift;
    my $accessions = $self->accessions();
    if ($accessions) {
        return shift @$accessions;
    }
    return;
}

__PACKAGE__->meta->make_immutable;

1;