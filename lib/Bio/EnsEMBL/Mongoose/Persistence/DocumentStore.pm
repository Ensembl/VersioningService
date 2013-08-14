package Bio::EnsEMBL::Mongoose::Persistence::DocumentStore;

use Moose::Role;

# Lingo here is mainly themed to match Lucy/Lucene terminology.

# Defines the schema of the document that a Record maps to. 
# Includes definitions of which fields are binary, or need to be indexed
has schema => (
    is => 'ro',
    isa => 'Obj',
    lazy => 1,
    default => sub { },
);

# The location on disk of the document store.
has index => (
    is => 'rw',
    isa => 'Str',
);

# The document store indexing object, used for loading documents into the store
has indexer => (
    is => 'ro',
    isa=> 'Obj',
    lazy => 1,
    default => sub { },
);

# Explicitly tell the document store to keep a document.
sub store_record {
    
}

# Call for the document store to commit any documents. Called to ensure transactional behaviour.
sub commit {
    
}


1;