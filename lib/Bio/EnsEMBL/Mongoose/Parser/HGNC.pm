package Bio::EnsEMBL::Mongoose::Parser::HGNC;
use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::IO::ColumnBasedParser;

use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

# Consumes HGNC file and emits Mongoose::Persistence::Records
with 'MooseX::Log::Log4perl';

# 'uni','http://uniprot.org/uniprot'
with 'Bio::EnsEMBL::Mongoose::Parser::TextParser';

sub read_record {
    my $self = shift;
    my $content = $self->slurp_content;
    if (!$content) { return; }
    $self->clear_record;
    $self->node_sieve();
    return 1;
}

sub node_sieve {
  my $self = shift;
  $self->accession();
  $self->display_label();
  $self->synonyms();
  $self->xref();
}


sub accession {
  my $self = shift;
  my $accession = $self->getRawAccession();
  $self->record->accessions([$accession]) if $accession;
}

sub getRawAccession {
  my $self = shift;
  return $self->{'current_block'}[0];
}

sub display_label {
  my $self = shift;
  my $display_label = $self->getRawLabel;
  $self->record->display_label($display_label) if $display_label;
}

sub getRawLabel {
  my $self = shift;
  return $self->{'current_block'}[1];
}

sub synonyms {
  my $self = shift;
  my $synonyms = $self->getRawSynonyms;
  foreach my $synonym (@$synonyms) {
    $self->record->add_synonym($synonym);
  }
}

sub getRawSynonyms {
  my $self = shift;
  my @synonyms = split(', ', $self->{'current_block'}[8]);
  return \@synonyms;
}

sub xref {
  my $self = shift;
  my ($source, $xref);
  my $refseq_xrefs = $self->getRawRefseqXrefs;
  foreach my $refseq_xref (@$refseq_xrefs) {
    $source = 'RefSeq';
    $xref = Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source, id => $refseq_xref);
    $self->record->add_xref($xref);
  }
  my $ensembl_xrefs = $self->getRawEnsemblXrefs;
  foreach my $ensembl_xref (@$ensembl_xrefs) {
    $source = 'Ensembl';
    $xref = Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source, id => $ensembl_xref);
    $self->record->add_xref($xref);
  }
}

sub getRawRefseqXrefs {
  my $self = shift;
  my @refseq_xrefs = split(', ', $self->{'current_block'}[23]);
  return \@refseq_xrefs;
}

sub getRawEnsemblXrefs {
  my $self = shift;
  my @ensembl_xrefs = split(', ', $self->{'current_block'}[18]);
  return \@ensembl_xrefs;
}

sub check_header {
  my $self = shift;
  my $content = shift;
  my @line = split($self->delimiter, $content);
  if ($line[0] ne 'HGNC ID') {
    $self->log->fatal("Column " . $line[0] . " does not match HGNC ID");
  }
  if ($line[1] ne 'Approved Symbol') {
    $self->log->fatal("Column " . $line[1] . " does not match Approved Symbol");
  }
  if ($line[2] ne 'Approved Name') {
    $self->log->fatal("Column " . $line[2] . " does not match Approved Name");
  }
  if ($line[8] ne 'Synonyms') {
    $self->log->fatal("Column " . $line[8] . " does not match Synonyms");
  }
  if ($line[15] ne 'Accession Numbers') {
    $self->log->fatal("Column " . $line[15] . " does not match Accession Numbers");
  }
  if ($line[18] ne 'Ensembl Gene ID') {
    $self->log->fatal("Column " . $line[18] . " does not match Ensembl Gene ID");
  }
  if ($line[23] ne 'RefSeq IDs') {
    $self->log->fatal("Column " . $line[23] . " does not match RefSeq IDs");
  }
  return $line[0];
}

__PACKAGE__->meta->make_immutable;

1;
