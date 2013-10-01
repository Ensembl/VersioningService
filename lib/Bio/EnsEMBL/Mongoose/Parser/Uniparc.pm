package Bio::EnsEMBL::Mongoose::Parser::Uniparc;
use Moose;
use Moose::Util::TypeConstraints;

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

# Consumes Swissprot file and emits Mongoose::Persistence::Records
with 'MooseX::Log::Log4perl';

# 'uni','http://uniprot.org/uniprot'
with 'Bio::EnsEMBL::Mongoose::Parser::XMLParser';

around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;
    # Add some default parameters to the parser
    $args{short_namespace} = 'uni';
    $args{namespace} = 'http://uniprot.org/uniparc';
    $class->$orig(%args);
    
};

sub read_record {
    my $self = shift;
    my $reader = $self->xml_reader;
    
    my $record = $self->record;
    $self->clear_record;

    my $read_state;
    # fast-forward to next <entry> and extract attributes
    
    unless ($reader->name && $reader->name eq "entry") {
        $read_state = $reader->nextElement("entry");
        if ($read_state == 0) {return 0}
    }
    my $node = $reader->copyCurrentNode(1); # 1 = deep copy
    # copyCurrentNode(1) does not spool the cursor to the end-tag!
    
    $self->node_sieve($node);
    $self->detach($node);
    # move off <entry> node so unless(){} above can work next time.
    $reader->next;
    return $read_state;
}

sub node_sieve {
    my $self = shift;
    my $node = shift;
    $self->log->debug('Parsing XML subtree.');
    
    $self->accession($node);
    $self->sequence($node);
    $self->xrefs($node);
    return 1;
}


# Filtering out only Ensembl Xrefs for the purposes of the old xref pipeline.
sub xrefs {
    my $self = shift;
    my $node = shift;
    my $node_list = $self->xpath_context->findnodes('/uni:uniparc/uni:entry/uni:dbReference[@type="ENSEMBL"]',$node);
    
    $node_list->foreach( sub {
        my $node = shift;
        my @attributes = $node->attributes();
        my ($source,$id);
        foreach my $attr (@attributes) {
            if ($attr->nodeName eq 'type') {$source = $attr->value}
            elsif ($attr->nodeName eq 'id') {$id = $attr->value}
        }
        my $xref = Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source, id => $id);
        
        $self->record->add_xref($xref);
    });
}

sub accession {
    my $self = shift;
    my $node = shift;
    my $node_list = $self->xpath_context->findnodes('/uni:uniparc/uni:entry/uni:accession',$node);
    
    # Uniparc has no primary accession, so we store them all equally.
    my @accessions = $node_list->map(sub {$_->textContent});
    $self->record->accessions(\@accessions);
    $self->log->debug('Primary Accesion: '.$accessions[0]. ' and '.scalar(@accessions).' in total');
}

sub sequence {
    my $self = shift;
    my $node = shift;
    my $node_list = $self->xpath_context->findnodes('/uni:uniparc/uni:entry/uni:sequence',$node);
    my $seq_node = $node_list->shift;
#    my $sequence = $seq_node->textContent;
#    $sequence =~ s/\s+//g;
#    $self->record->sequence($sequence);
    # Want checksum in the attribute
    my @attributes = $seq_node->attributes();
    
    foreach my $attr (@attributes) {
        if ($attr->nodeName eq 'checksum') {$self->record->checksum($attr->value)}
        elsif ($attr->nodeName eq 'length') {$self->record->sequence_length($attr->value)}
    }
    
}

1;