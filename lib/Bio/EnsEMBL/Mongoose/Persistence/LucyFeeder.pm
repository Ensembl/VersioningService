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

=cut

package Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;

use Moose;
use Moose::Util::TypeConstraints;

use Bio::EnsEMBL::Mongoose::Persistence::Record;

use Lucy::Index::Indexer;
use Lucy::Plan::Schema;
use Lucy::Plan::StringType;
use Lucy::Plan::BlobType;
use Lucy::Plan::FullTextType;
use Lucy::Analysis::StandardTokenizer;
use Sereal qw/encode_sereal/;

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
        my $analyzer = Lucy::Analysis::StandardTokenizer->new;
        my $lucy_text = Lucy::Plan::FullTextType->new(
            analyzer => $analyzer,
            sortable => 1,
        );
        
        # Use Moose MOP to get all attributes of the Record to create a schema for Lucy
        # Treat sequence as a special case so it does not get indexed.
        my $record_meta = Bio::EnsEMBL::Mongoose::Persistence::Record->meta();
        for my $attribute ($record_meta->get_all_attributes) {
            if ($attribute->name eq 'sequence' ) {
                $schema->spec_field( name => 'sequence', type => $lucy_blob );
            } elsif ($attribute->name eq 'accessions') {
                $schema->spec_field( name => 'accessions', type => $lucy_text);
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
        my $create = 1;
        if (-e $self->index) {
            $create = 0;
        }  
        return Lucy::Index::Indexer->new(
            schema => $self->schema,
            index => $self->index,
            create => $create,
        );
    }
);

with 'Bio::EnsEMBL::Mongoose::Persistence::DocumentStore','MooseX::Log::Log4perl';

sub store_record {
    my $self = shift;
    my $record = shift;
    
    # record must be processed into separate fields, because Lucy does not understand arrays.
    my %flattened_record;
    %flattened_record = %{$record};
    if (exists $flattened_record{accessions}) {
        my @accessions = @{$flattened_record{accessions}};
        $flattened_record{accessions} = join ' ',@accessions;
    }
    # could also define a ->reduce handler in Record
    if (exists $flattened_record{synonyms}) {
        my @synonyms = @{$flattened_record{synonyms}};
        $flattened_record{synonyms} = join ' ',@synonyms;
    }
    if (exists $flattened_record{isoforms}) {
        my @isoforms = @{$flattened_record{isoforms}};
        $flattened_record{isoforms} = join ' ',@isoforms;
    }
    # Throw out pointless duplicates
    if (exists $flattened_record{'sequence'}) {delete $flattened_record{'sequence'}};
    if (exists $flattened_record{'xref'}) {delete $flattened_record{'xref'}};
    if (exists $flattened_record{'isoforms'}) {delete $flattened_record{'isoforms'}};
    # blob the record into the docstore for restoration on query
    $flattened_record{blob} = $self->compress_sereal($record);
    
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
