package Bio::EnsEMBL::Mongoose::Parser::Refseq;
use Moose;
use Moose::Util::TypeConstraints;
use Data::Dump::Color qw/dump/;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

use Bio::EnsEMBL::IO::Parser::GenbankParser;
use Bio::EnsEMBL::Mongoose::Taxonomizer;



# Requires access to compara taxonomy database, due to lack of taxon ID in Refseq files

has 'genbank_parser' => (
    isa => 'Bio::EnsEMBL::IO::Parser::GenbankParser',
    is => 'ro',
    builder => '_ready_parser',
    lazy => 1,
);

has 'taxonomizer' => (
    isa => 'Bio::EnsEMBL::Mongoose::Taxonomizer',
    is => 'ro',
    lazy => 1,
    default => sub {
        return Bio::EnsEMBL::Mongoose::Taxonomizer->new;
    }
);

# Consumes Refseq files and emits Mongoose::Persistence::Records
with 'Bio::EnsEMBL::Mongoose::Parser::Parser';
with 'MooseX::Log::Log4perl';

sub read_record {
    my $self = shift;
    $self->clear_record;
    
    my $parser = $self->genbank_parser;
    my $read_state = $parser->next;
    if ($read_state == 0) {return 0}
    my $taxon = $self->determine_taxon;
    $self->record->taxon_id($taxon);
    #next unless $taxon;
    $self->record->id($parser->getLocusId);
    $self->record->accessions([$parser->getAccession]);
    my $sequence = $parser->getSequence();
    if ($sequence) {
        $self->record->sequence( $sequence );
        $self->record->sequence_length(length($sequence));
    }
    $self->record->description( $parser->getDescription() );
    $self->chew_description;
    $self->record->version($parser->getSeqVersion);
    my $db_links = $parser->getRawDBLinks;
    if ($db_links) {
        my $xrefs = $self->chew_dblinks($db_links);
        $self->record->xref($xrefs);
    }

    return $read_state;
}

sub _ready_parser {
    my $self = shift;
    return Bio::EnsEMBL::IO::Parser::GenbankParser->open($self->source_file);
}

# Pulls gene name from the lines of DEFINITION
# PREDICTED: Macaca fascicularis cathepsin C (CTSC), transcript
#            variant X3, mRNA.
# It's in brackets, not at all ambiguous..
sub chew_description {
    my $self = shift;
    my $description = $self->record->description;
    my ($gene_name) = ($description =~ /\((.+?)\)/);
    $self->record->gene_name($gene_name) if ($gene_name);
}

# Transform a word-based taxonomy into a taxon ID
sub determine_taxon {
    my $self = shift;
    my $beastie = $self->genbank_parser->getOrganism;
    my @ranks = split /; /,$beastie;
    my $name = $ranks[-1];
    $name =~ s/.\s*$//;
    my $taxon = $self->taxonomizer->fetch_taxon_id_by_name($name);
    return $taxon;
}


# Method for turning DBLINK fields into Xref records
sub chew_dblinks {
    my $self = shift;
    my $dblink_field = shift;
    my @lines = split /\n/,$dblink_field;
    my @xrefs;
    foreach (@lines) {
        my ($label, $value) = ($_ =~ /\s*(.+)?:\s*(\w+)/);
        if ($label && $value) {
            my $xref = Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $label, id => $value);
            push @xrefs,$xref;
        }
    }
    return \@xrefs;
}