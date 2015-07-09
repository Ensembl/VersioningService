# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Bio::EnsEMBL::Mongoose::Parser::Refseq;
use Moose;
use Moose::Util::TypeConstraints;
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
    $self->record->taxon_id($taxon) if ($taxon);
    my $id = $parser->get_locus_id;
    $self->record->id($id) if ($id);
    my $accession = $parser->get_accession;
    $self->record->accessions([$accession]) if ($accession);
    my $sequence = $parser->get_sequence();
    if ($sequence) {
        $self->record->sequence( $sequence );
        $self->record->sequence_length(length($sequence));
    }
    my $description = $parser->get_description();
    if ($description) {
        $self->record->description( $description );
        $self->chew_description;
    }
    my $comment = join("\n",$parser->get_raw_comment);
    if ($comment) {
        $self->record->comment( $comment );
    }
    my $seq_version = $parser->get_sequence_version;
    if ($seq_version) {
        $self->record->version($seq_version);
    }
    my $db_links = $parser->get_raw_dblinks;
    if ($db_links) {
        my $xrefs = $self->chew_dblinks($db_links);
        $self->record->xref($xrefs);
    }

    if (!($id || $taxon || $accession)) {
        $self->log->info('Partial record. $id,$taxon, from '.$self->genbank_parser->{filename});
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
    my $name = $self->genbank_parser->get_organism;
    return unless ($name);
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