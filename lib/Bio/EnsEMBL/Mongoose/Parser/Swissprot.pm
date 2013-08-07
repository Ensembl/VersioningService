package Bio::EnsEMBL::Mongoose::Parser::Swissprot;
use Moose;
use Moose::Util::TypeConstraints;

use XML::LibXML::Reader;
use XML::LibXML::XPathContext;
use Bio::EnsEMBL::Mongoose::Parser::Record;


# Consumes Swissprot file and emits Mongoose::Parser::Records
extends 'Bio::EnsEMBL::Mongoose::Parser::Parser';

has 'record' => (
    is => 'rw',
    isa => 'Bio::EnsEMBL::Mongoose::Parser::Record',
    lazy => 1,
    default => sub {
        return Bio::EnsEMBL::Mongoose::Parser::Record->new;
    }
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

has 'xpath_context' => (
    is => 'ro',
    isa => 'XML::LibXML::XPathContext',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $xpc = XML::LibXML::XPathContext->new();
        $xpc->registerNs('uni','http://uniprot.org/uniprot');
        return $xpc;
    }
);


sub read_record {
    my $self = shift;
    my $reader = $self->xml_reader;
    
    my $record = $self->record;
    
    # fast-forward to next <entry> and extract attributes
    unless ($reader->name && $reader->name eq "entry") {
        $reader->nextElement("entry");
    }
    $record->version($reader->getAttribute("version"));
    

    my $node = $reader->copyCurrentNode(1); # 1 = deep copy
    $self->node_sieve($node);
    
    
}

sub node_sieve {
    my $self = shift;
    my $node = shift;
    $self->accession($node);
    
    # note: can always fetch child nodes with $node->getElementsByTagName
    return 1;
}

sub accession {
    my $self = shift;
    my $node = shift;
    my $node_list = $self->xpath_context->findnodes('//uni:accession',$node);
    
    print $node_list->size."\n";
    $node_list->foreach(sub {print $_->localname." ".$_->toString."\n"});
    # First node is "primary accession"
    my ($accession,@others) = $node_list->map(sub {$_->textContent});
    $self->record->primary_accession($accession);
    $self->record->accessions(\@others);
}




sub persist_record {
    my $self = shift;
    return 1;
}

1;