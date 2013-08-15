package Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;

use Moose;
use Moose::Util::TypeConstraints;

use Bio::EnsEMBL::Mongoose::Persistence::Record;

use Lucy::Index::Indexer;
use Lucy::Plan::Schema;
use Lucy::Plan::StringType;
use Lucy::Plan::BlobType;

subtype 'Lucy::Plan::Schema' => as 'Object';

has schema => (
    is => 'ro',
    isa => 'Lucy::Plan::Schema',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $schema = Lucy::Plan::Schema->new;
        my $lucy_str = Lucy::Plan::StringType->new(
            sortable => 1,
        );
        my $lucy_blob = Lucy::Plan::BlobType->new(
            stored => 1,
        );
        
        # Use Moose MOP to get all attributes of the Record to create a schema for Lucy
        # Treat sequence as a special case so it does not get indexed.
        my $record_meta = Bio::EnsEMBL::Mongoose::Persistence::Record->meta();
        for my $attribute ($record_meta->get_all_attributes) {
            if ($attribute->name eq 'sequence') {
                $schema->spec_field( name => 'sequence', type => $lucy_blob );
            } else {
                $schema->spec_field( name => $attribute->name, type => $lucy_str);
            }
        }
        
        return $schema;
    },
);

has index => (
    is => 'rw',
    isa => 'Str',
    default => '/Users/ktaylor/projects/data/mongoose.index',
);

has indexer => (
    is => 'ro',
    isa=> 'Lucy::Index::Indexer',
    lazy => 1,
    default => sub {
        my $self = shift;
        return Lucy::Index::Indexer->new(
            schema => $self->schema,
            index => $self->index,
            create => 1,
        );
    }
);
with 'Bio::EnsEMBL::Mongoose::Persistence::DocumentStore';

sub store_record {
    my $self = shift;
    my $record = shift;
    
    
    
    $self->indexer->add_doc(
#        primary_accession => $record->primary_accession,
#        taxon_id => $record->taxon_id,
#        gene_name => $record->gene_name,
#        sequence => $record->sequence,
#        evidence_level => $record->evidence_level,
        $record
    );
}

sub commit {
    my $self = shift;
    $self->indexer->commit;
}


__PACKAGE__->meta->make_immutable;

1;