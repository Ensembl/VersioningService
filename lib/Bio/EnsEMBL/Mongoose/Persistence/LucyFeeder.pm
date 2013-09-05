package Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;

use Moose;
use Moose::Util::TypeConstraints;

use Bio::EnsEMBL::Mongoose::Persistence::Record;

use Lucy::Index::Indexer;
use Lucy::Plan::Schema;
use Lucy::Plan::StringType;
use Lucy::Plan::BlobType;

use JSON::XS;

#subtype 'Lucy::Plan::Schema' => as 'Object';

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
            if ($attribute->name eq 'sequence' ) {
                $schema->spec_field( name => 'sequence', type => $lucy_blob );
            } else {
                $schema->spec_field( name => $attribute->name, type => $lucy_str);
            }
        }
        
        # Add on bonus blob field
        
        $schema->spec_field( name => 'blob', type => $lucy_blob);
        
        return $schema;
    },
);

has index => (
    is => 'rw',
    isa => 'Str',
    default => '$ENV{HOME}/mongoose.index',
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

has json_encoder => (
    is => 'ro',
    isa => 'Object',
    default => sub {
        my $json = JSON::XS->new;
        $json->allow_blessed(1);
        $json->convert_blessed(1);
        return $json;
    }
);

with 'Bio::EnsEMBL::Mongoose::Persistence::DocumentStore';
with 'MooseX::Log::Log4perl';

sub store_record {
    my $self = shift;
    my $record = shift;
    
    # record must be processed into separate fields, because Lucy does not understand arrays.
    my %flattened_record;
    %flattened_record = %{$record};
    my @accessions = @{$flattened_record{accessions}};
    $flattened_record{accessions} = join ' ',@accessions;
    # could also define a ->reduce handler in Record
    if (exists $flattened_record{synonyms}) {
        my @synonyms = @{$flattened_record{synonyms}};
        $flattened_record{synonyms} = join ' ',@synonyms;
    }
    # Throw out pointless duplicates
    if (exists $flattened_record{'sequence'}) {delete $flattened_record{'sequence'}};
    if (exists $flattened_record{'xref'}) {delete $flattened_record{'xref'}};
    # blob the record into the docstore for restoration on query
    
    #$self->log->debug($json->encode($record));
    $flattened_record{blob} = $self->json_encoder->encode($record);
    
    $self->indexer->add_doc(
        \%flattened_record
    );
}

sub commit {
    my $self = shift;
    $self->indexer->commit;
}


__PACKAGE__->meta->make_immutable;

1;