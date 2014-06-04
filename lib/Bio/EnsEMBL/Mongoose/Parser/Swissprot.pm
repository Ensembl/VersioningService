package Bio::EnsEMBL::Mongoose::Parser::Swissprot;
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
    $args{namespace} = 'http://uniprot.org/uniprot';
    $args{top_tag} = 'uniprot';
    $class->$orig(%args);
};

sub read_record {
    my $self = shift;
    $self->flush_document;
    my $slurp = $self->slurp_content;
    if (!$slurp) {return;}
    #my $doc = $self->xml_document;
    $self->clear_record;
    $self->log->debug('Record blanked');
    my $read_state = $self->node_sieve();
    return $read_state;
}

sub node_sieve {
    my $self = shift;

    $self->log->debug('Parsing XML subtree.');
    my $state = $self->accession();
    $self->synonyms();
    $self->gene_name();
    $self->entry_name();
    $self->protein_name();
    $self->sequence_version();
    $self->xrefs();
    $self->description();
    $self->sequence();
    $self->taxon();
    $self->evidence_level();
    if ($self->suspicious()) {$self->log->debug("Found an untrustworthy Xref")}
    # note: can always fetch child nodes with $node->getElementsByTagName
    return 1 if $state >0;
}


sub accession {
    my $self = shift;
    my $node_list = $self->xpath_context->findnodes('//uni:accession',$self->xml_document);
    
    # First node is "primary accession"
    my (@accessions) = $node_list->map(sub {$_->textContent});
    $self->record->accessions(\@accessions);
    $self->log->debug('Primary Accesion: '.$accessions[0]. ' and '.scalar(@accessions).' total accessions');
    return scalar(@accessions);
}

sub gene_name {
    my $self = shift;
    $self->record->gene_name($self->xpath_to_value('/uni:uniprot/uni:entry/uni:gene/uni:name[@type="primary"]'));
}

sub entry_name {
    my $self = shift;
    $self->record->entry_name($self->xpath_to_value('/uni:uniprot/uni:entry/uni:name'));
}

sub protein_name {
    my $self = shift;
    $self->record->protein_name($self->xpath_to_value('/uni:uniprot/uni:entry/uni:protein/uni:recommendedName/uni:fullName'));
}

sub sequence_version{
    my $self = shift;
    $self->record->sequence_version($self->xpath_to_value('/uni:uniprot/uni:entry/uni:sequence/@version'));
}

sub synonyms {
    my $self = shift;
    my $xpath = '/uni:uniprot/uni:entry/uni:gene/uni:name[@type="synonym"]';
    my $node_list = $self->xpath_context->findnodes($xpath,$self->xml_document);
    $node_list->foreach( sub {
        # This is a list of LibXML::Elements, a subclass of Node. Data is found in textContent, not in Value!
        #print $_->toString."\n";
        $self->record->add_synonym($_->textContent);
    });
}

sub sequence {
    my $self = shift;
    my $sequence = $self->xpath_to_value('/uni:uniprot/uni:entry/uni:sequence');
    $sequence =~ s/\s+//g;
    $self->record->sequence($sequence);
    $self->record->sequence_length(length($sequence));
}

sub taxon {
    my $self = shift;
    $self->record->taxon_id($self->xpath_to_value('/uni:uniprot/uni:entry/uni:organism/uni:dbReference[@type="NCBI Taxonomy"]/@id'));
}

# /uni:uniprot/uni:entry/uni:dbReference
sub xrefs {
    my $self = shift;
    
    my $xpath = '/uni:uniprot/uni:entry/uni:dbReference';
    my $node_list = $self->xpath_context->findnodes($xpath, $self->xml_document);
    
    $node_list->foreach( sub {
        my $node = shift;
        my @attributes = $node->attributes();
        my ($source,$id,$active,$last);
        foreach my $attr (@attributes) {
            if ($attr->nodeName eq 'type') {$source = $attr->value}
            elsif ($attr->nodeName eq 'id') {$id = $attr->value}
            elsif ($attr->nodeName eq 'active') {
                $active = ($attr->value eq 'Y') ? 1 : 0;
            }
            elsif ($attr->nodeName eq 'last' && !$active) {
                $last = $attr->value;
            }
        }
        my $xref = Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source, id => $id);
        
        $self->record->add_xref($xref);
    });
}

# /uni:uniprot/uni:entry/uni:proteinExistence/@type
sub evidence_level {
    my $self = shift;
    my $level = 0;
    my $evidence = $self->xpath_to_value('/uni:uniprot/uni:entry/uni:proteinExistence/@type');
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
    my $worry = $self->xpath_to_value('/uni:uniprot/uni:entry/uni:comment[@type="caution"]/uni:text');
    if ($worry && $worry =~ /Ensembl automatic/) {
        $self->record->suspicion("Ensembl");
        return 1;
    }
    return;
}

sub description {
    my $self = shift;
    $self->record->description($self->xpath_to_value('/uni:uniprot/uni:entry/uni:comment[@type="function"]/uni:text'));
}

__PACKAGE__->meta->make_immutable;

1;