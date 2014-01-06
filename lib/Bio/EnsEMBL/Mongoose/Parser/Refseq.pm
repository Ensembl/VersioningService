package Bio::EnsEMBL::Mongoose::Parser::Refseq;
use Moose;
use Moose::Util::TypeConstraints;
use Data::Dump::Color qw/dump/;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

# Requires access to compara taxonomy database, due to lack of taxon ID in Refseq files

has 'genbank_parser' => (
    isa => 'Bio::EnsEMBL::IO::Parser::GenbankParser',
    is => 'ro',
    builder => '_ready_parser',
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
    
    my $parser = $self->genbank_parser;
    $parser->next;

    my $taxon = $self->determine_taxon;
    next unless $taxon;
    $self->record->id($parser->getLocusId);
    $self->record->accession->push($parser->get_accession);
    $self->record->sequence( $parser->sequence() );
    $self->record->sequence_length(length($self->record->sequence));
    $self->record->description( $description );
    $self->chew_description;
    $self->record->version($parser->getSeqVersion);
    my $xrefs = $self->chew_dblinks($parser->getRawDBLinks);
    $self->record->xref($xrefs);



    $self->clear_record;

    return $read_state;
}

sub _ready_parser {
    my $self = shift;
    return $parser = Bio::EnsEMBL::IO::Parser::GenbankParser->open($self->source_file);
}

# Pulls gene name from the lines of DEFINITION
# PREDICTED: Macaca fascicularis cathepsin C (CTSC), transcript
#            variant X3, mRNA.
# It's in brackets, not at all ambiguous..
sub chew_description {
    my $self = shift;
    my $description = $self->description;
    my ($gene_name) = $description =~ /\((.+)\)/;
    $self->record->gene_name($gene_name);
}

sub determine_taxon {
    my $self = shift;
    my $beastie = $parser->getOrganism;
    my ($name) = $beastie =~ /^(.*)\n/;
    my $taxon = $self->taxonomizer->convert_name_to_taxon($name);
    return $taxon;
}

sub chew_dblinks {
    my $self = shift;
    my $dblink_field = shift;
    my @lines = split /\n/,$dblink_field;
    my @xrefs;
    foreach (@lines) {
        my ($label, $value) = $_ =~ /\s*(.+):(\w+)/;
        if ($label && $value) {
            my $xref = Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source, id => $value);
            push @xrefs,$xref;
        }
    }
    return \@xrefs;
}