package Bio::EnsEMBL::Mongoose::Parser::Swissprot;
use Moose;
use Moose::Util::TypeConstraints;

use XML::LibXML::Reader;
use Bio::EnsEMBL::Mongoose::Parser::Record;


# Consumes Swissprot file and emits Mongoose::Parser::Records
extends 'Bio::EnsEMBL::Mongoose::Parser::Parser';

has 'record' => (
    is => 'rw',
    isa => 'Bio::EnsEMBL::Mongoose::Parser::Record',
);

subtype 'XML::LibXML::Reader' => as 'Object';

coerce 'XML::LibXML::Reader' => from 'Str' => via {
    XML::LibXML::Reader->new( location => $_);
};

has 'xml_reader' => (
    is => 'ro',
    isa => 'XML::LibXML::Reader',
    coerce => 1,
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->source_file;
    }
);


sub processNode {
    my $self = shift;
    my $reader = shift;
    print $reader->name ."\n";
}


sub read_record {
    my $self = shift;
    my $reader = $self->xml_reader;
    for (1..100) {
        $reader->read;
        $self->processNode($reader);
    }
}

1;