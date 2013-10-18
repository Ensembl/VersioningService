package Bio::EnsEMBL::Mongoose::Parser::Uniparc;
use Moose;
use Moose::Util::TypeConstraints;
use Data::Dump::Color qw/dump/;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

# Consumes Swissprot file and emits Mongoose::Persistence::Records
with 'MooseX::Log::Log4perl';

with 'Bio::EnsEMBL::Mongoose::Parser::XMLParser';

around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;
    # Add some default parameters to the parser
    $args{short_namespace} = 'uni';
    $args{namespace} = 'http://uniprot.org/uniparc';
    $args{top_tag} = 'uniparc';
    $class->$orig(%args);    
};

sub read_record {
    my $self = shift;
    $self->flush_document;
    my $slurp = $self->slurp_content;
    if (!$slurp) {return;}
    #my $doc = $self->xml_document;
    $self->clear_record;
    my $read_state = $self->node_sieve();
    return $read_state;
}

sub node_sieve {
    my $self = shift;
    $self->log->debug('Parsing XML subtree.');
    
    my $state = $self->accession();
    $self->sequence();
    $self->xrefs();
    return 1 if $state >0;
}


# Filtering out only Ensembl Xrefs for the purposes of the old xref pipeline.
sub xrefs {
    my $self = shift;
    # /uni:uniparc/uni:entry/uni:dbReference[@type="ENSEMBL"]
    my $node_list = $self->xpath_context->findnodes('/uni:uniparc/uni:entry/uni:dbReference[@type="ENSEMBL"]',$self->xml_document);
    
    my $record = $self->record;
    $node_list->foreach( sub {
        my $node = shift;
        my @attributes = $node->attributes();
        my ($source,$id);
        foreach my $attr (@attributes) {
            if ($attr->nodeName eq 'type') {$source = $attr->value}
            elsif ($attr->nodeName eq 'id') {$id = $attr->value}
        }
        my $xref = Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source, id => $id);
        
        $record->add_xref($xref);
    });
}

sub accession {
    my $self = shift;
    my $node_list = $self->xpath_context->findnodes('/uni:uniparc/uni:entry/uni:accession',$self->xml_document);
    
    # Uniparc has no primary accession, so we store them all equally.
    my @accessions = $node_list->map(sub {$_->textContent});
    $self->record->accessions(\@accessions);
    $self->log->debug('Primary Accesion: '.$accessions[0]. ' and '.scalar(@accessions).' in total');
    return scalar(@accessions);
}

sub sequence {
    my $self = shift;
    my $node_list = $self->xpath_context->findnodes('/uni:uniparc/uni:entry/uni:sequence',$self->xml_document);
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