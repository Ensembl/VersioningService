package Bio::EnsEMBL::Mongoose::Parser::Swissprot;
use Moose;
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
    $self->synonyms($node);
    $self->gene_name($node);
    $self->xrefs($node);
    $self->description($node);
    $self->sequence($node);
    $self->taxon($node);
    $self->evidence_level($node);
    if ($self->suspicious($node)) {$self->log->debug("Found an untrustworthy Xref")}
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

sub synonyms {
    my $self = shift;
    my $node = shift;
    my $xpath = '/uni:uniprot/uni:entry/uni:gene/uni:name[@type="synonym"]';
    my $node_list = $self->xpath_context->findnodes($xpath, $node);
    $node_list->foreach( sub {
        # This is a list of LibXML::Elements, a subclass of Node. Data is found in textContent, not in Value!
        #print $_->toString."\n";
        $self->record->add_synonym($_->textContent);
    });
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

# /uni:uniprot/uni:entry/uni:dbReference
sub xrefs {
    my $self = shift;
    my $node = shift;
    
    my $xpath = '/uni:uniprot/uni:entry/uni:dbReference';
    my $node_list = $self->xpath_context->findnodes($xpath, $node);
    
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

# /uni:uniprot/uni:entry/uni:proteinExistence/@type
sub evidence_level {
    my $self = shift;
    my $node = shift;
    my $level = 0;
    my $evidence = $self->xpath_to_value($node,'/uni:uniprot/uni:entry/uni:proteinExistence/@type');
    $self->log->debug("Evidence code: $evidence");
    
    $level = 1 if $evidence =~ /evidence at protein level/;
    $level = 2 if $evidence =~ /evidence at transcript level/;
    $level = 3 if $evidence =~ /inferred from homology/;
    $level = 4 if $evidence =~ /predicted/;
    $level = 5 if $evidence =~ /uncertain/;
    
    $self->log->debug("Coded to level $level");
    $self->record->evidence_level($level);
}
# Used for finding comments that indicate a reference is unreliable
sub suspicious {
    my $self = shift;
    my $node = shift;
    
    my $worry = $self->xpath_to_value($node,'/uni:uniprot/uni:entry/uni:comment[@type="caution"]/uni:text');
    if ($worry && $worry =~ /Ensembl automatic/) {
        $self->record->suspicion("Ensembl");
        return 1;
    }
    return;
}

sub description {
    my $self = shift;
    my $node = shift;
    $self->record->description($self->xpath_to_value($node,'/uni:uniprot/uni:entry/uni:comment[@type="function"]/uni:text'));
}

sub xpath_to_value {
    my $self = shift;
    my $node = shift;
    my $xpath = shift;
    
    my $node_list = $self->xpath_context->findnodes($xpath, $node);
    if ($node_list->size > 0) {
        return $node_list->shift->textContent;
    } else {
        $self->log->debug("Xpath returned nowt, ".$xpath);
        return;
    }
}

__PACKAGE__->meta->make_immutable;

1;