package Bio::EnsEMBL::Mongoose::Parser::XMLParser;
use Moose::Role;
use Moose::Util::TypeConstraints;

use XML::LibXML::Reader;
use XML::LibXML::XPathContext;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

# Consumes Swissprot file and emits Mongoose::Persistence::Records
with 'MooseX::Log::Log4perl';

has record => (
    is => 'rw',
    isa => 'Bio::EnsEMBL::Mongoose::Persistence::Record',
    lazy => 1,
    default => sub {
        return Bio::EnsEMBL::Mongoose::Persistence::Record->new;
    },
    clearer => 'clear_record',
);

subtype 'XML::LibXML::Reader' => as 'Object';

coerce 'XML::LibXML::Reader' => from 'GlobRef' => via {
    XML::LibXML::Reader->new( IO => $_);
};

has xml_reader => (
    is => 'ro',
    isa => 'XML::LibXML::Reader',
    coerce => 1,
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->source_handle;
    }
);

has xpath_context => (
    is => 'ro',
    isa => 'XML::LibXML::XPathContext',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $xpc = XML::LibXML::XPathContext->new();
        $xpc->registerNs($self->short_namespace,$self->namespace);
        return $xpc;
    }
);

has namespace => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has short_namespace => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

with 'Bio::EnsEMBL::Mongoose::Parser::Parser';


1;