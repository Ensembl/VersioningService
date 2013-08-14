package Bio::EnsEMBL::Mongoose::Parser::Swissprot;
use Moose;
use Moose::Util::TypeConstraints;

use XML::LibXML::Reader;
use XML::LibXML::XPathContext;
use Bio::EnsEMBL::Mongoose::Parser::Record;


# Consumes Swissprot file and emits Mongoose::Parser::Records
with 'MooseX::Log::Log4perl';

has record => (
    is => 'rw',
    isa => 'Bio::EnsEMBL::Mongoose::Parser::Record',
    lazy => 1,
    default => sub {
        return Bio::EnsEMBL::Mongoose::Parser::Record->new;
    },
    clearer => 'clear_record',
);

subtype 'XML::LibXML::Reader' => as 'Object';

coerce 'XML::LibXML::Reader' => from 'Str' => via {
    XML::LibXML::Reader->new( location => $_);
};

has xml_reader => (
    is => 'ro',
    isa => 'XML::LibXML::Reader',
    coerce => 1,
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->source_file;
    }
);

has xpath_context => (
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

with 'Bio::EnsEMBL::Mongoose::Parser::Parser';

sub read_record {
    my $self = shift;
    my $reader = $self->xml_reader;
    
    my $record = $self->record;
    $self->clear_record;
    $self->log->debug('Record blanked');
    my $read_state;
    # fast-forward to next <entry> and extract attributes
    
    unless ($reader->name && $reader->name eq "entry") {
        $read_state = $reader->nextElement("entry");
        if ($read_state == 0) {return 0}
    }
    my $entry_version =$reader->getAttribute("version"); 
    if ($entry_version) {$record->version($entry_version);}
    
    my $node = $reader->copyCurrentNode(1); # 1 = deep copy
    # copyCurrentNode(1) does not spool the cursor to the end-tag!
    
    $self->node_sieve($node);
    # move off <entry> node so unless(){} above can work next time.
    $reader->next;
    return $read_state;
}

sub node_sieve {
    my $self = shift;
    my $node = shift;
    $self->log->debug('Parsing XML subtree.');
    $self->accession($node);
    $self->gene_name($node);
    $self->sequence($node);
    $self->taxon($node);
    # note: can always fetch child nodes with $node->getElementsByTagName
    return 1;
}

sub accession {
    my $self = shift;
    my $node = shift;
    my $node_list = $self->xpath_context->findnodes('//uni:accession',$node);
    
    # First node is "primary accession"
    my ($accession,@others) = $node_list->map(sub {$_->textContent});
    $self->record->primary_accession($accession);
    $self->record->accessions(\@others);
    $self->log->debug('Primary Accesion: '.$accession. ' and '.scalar(@others).' other accessions');
}

sub gene_name {
    my $self = shift;
    my $node = shift;
    $self->record->gene_name($self->xpath_to_value($node,'/uni:uniprot/uni:entry/uni:gene/uni:name[@type="primary"]'));
}

sub sequence {
    my $self = shift;
    my $node = shift;
    my $sequence = $self->xpath_to_value($node,'/uni:uniprot/uni:entry/uni:sequence');
    $sequence =~ s/\s+//g;
    $self->record->sequence($sequence);
    $self->record->sequence_length(length($sequence));
}

sub taxon {
    my $self = shift;
    my $node = shift;
    $self->record->taxon_id($self->xpath_to_value($node,'/uni:uniprot/uni:entry/uni:organism/uni:dbReference[@type="NCBI Taxonomy"]/@id'));
}

sub xpath_to_value {
    my $self = shift;
    my $node = shift;
    my $xpath = shift;
    
    my $node_list = $self->xpath_context->findnodes($xpath, $node);
    if ($node_list->size > 0) {
        return $node_list->shift->textContent;
    } else {
        print "Xpath returned nowt.\n";
        return;
    }
}

__PACKAGE__->meta->make_immutable;

1;