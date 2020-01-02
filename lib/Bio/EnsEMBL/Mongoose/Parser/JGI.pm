=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Mongoose::Parser::JGI

=head1 DESCRIPTION

A class to provide an object for parsing JGI fasta data for Ciona intestinalis.

=cut

package Bio::EnsEMBL::Mongoose::Parser::JGI;

use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::IO::Parser::Fasta;

use Try::Tiny;

has 'fasta_parser' => (
    isa => 'Bio::EnsEMBL::IO::Parser::Fasta',
    is => 'ro',
    builder => '_ready_parser',
    lazy => 1,
);

# Consumes JGI fasta files and emits Mongoose::Persistence::Records
with 'Bio::EnsEMBL::Mongoose::Parser::Parser','MooseX::Log::Log4perl';

sub read_record {
  my $self = shift;
  $self->clear_record;

  my $record = $self->record;
  my $parser = $self->fasta_parser;
    
  my $read_state;
  try {
    $read_state = $parser->next;
  } catch {
    Bio::EnsEMBL::Mongoose::IOException->throw('Parsing error '.$_.' in file ' . $self->fasta_parser->{filename});
  };
    
  return 0 if $read_state == 0;
  
  $record->taxon_id(7719); # this is assumed to be data for Ciona intestinalis
    
  my $accession = $parser->getHeader();
  $record->new_accession($accession);
  $record->display_label($accession);
  
  my $sequence = $parser->getSequence();
  if ($sequence) {
    $record->sequence(uc $sequence);
    $record->sequence_length(length($sequence));
  }

  $self->log->info('Partial record. $id, $taxon, from '.$self->fasta_parser->{filename})
    unless $accession and $record->taxon_id;

  return $read_state;
}

sub _ready_parser {
  my $self = shift;
  return Bio::EnsEMBL::IO::Parser::Fasta->open($self->source_handle);
}
