=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Mongoose::Parser::MiRBase;

use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::IO::Parser::EMBL;

# Requires access to compara taxonomy database, due to lack of taxon ID in miRBase files
use Bio::EnsEMBL::Mongoose::Taxonomizer;
use Try::Tiny;

has 'embl_parser' => (
    isa => 'Bio::EnsEMBL::IO::Parser::EMBL',
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

# Consumes miRBase files and emits Mongoose::Persistence::Records
with 'Bio::EnsEMBL::Mongoose::Parser::Parser','MooseX::Log::Log4perl';

#
# TODO
# Parse DR fields and create xrefs
#
sub read_record {
  my $self = shift;
  $self->clear_record;

  my $record = $self->record;
  my $parser = $self->embl_parser;
    
  my $read_state;
  try {
    $read_state = $parser->next;
  } catch {
    Bio::EnsEMBL::Mongoose::IOException->throw('Parsing error '.$_.' in file ' . $self->embl_parser->{filename});
  };
    
  return 0 if $read_state == 0;
  my $taxon = $self->get_taxon;
    
  $record->taxon_id($taxon) if $taxon;
    
  my $id = $parser->get_id;
  $record->id($id) if $id;
  $record->display_label($id);
  
  my $accessions = $parser->get_accessions;
  if ($accessions and scalar @{$accessions}) {
    $record->accessions($accessions);
  } else {
    Bio::EnsEMBL::Mongoose::IOException->throw("miRBase record $id has no accessible accession");
  }

  # database cross references
  my $xrefs = $parser->get_database_cross_references();
  foreach my $xref (@{$xrefs}) {
    my ($source, $primary_id) = split /:/, $xref;
    # skip TARGETS:PICTAR-VERT xrefs
    next if $source =~ /^TARGETS/;
    $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source, creator => 'MiRBase', id => $primary_id));
  }
  
  # get sequence, make uppercase and replace Ts for Us
  my $sequence = $parser->get_sequence();
  $sequence = uc($sequence);
  $sequence =~ s/U/T/g;
  if ($sequence) {
    $record->sequence($sequence);
    $record->sequence_length(length($sequence));
  }
    
  if (!($id || $taxon)) {
    $self->log->info('Partial record. $id,$taxon, from '.$self->embl_parser->{filename});
  }
    
  return $read_state;
}

sub _ready_parser {
  my $self = shift;
  return Bio::EnsEMBL::IO::Parser::EMBL->open($self->source_handle);
}

# Transform a word-based taxonomy into a taxon ID
sub get_taxon {
  my $self = shift;
  my $embl_parser = $self->embl_parser;
  
  # species scientific name is in description (DE) field
  my $species_name = join(' ', (split /\s/, $embl_parser->get_description())[0,1]);
  return unless ($species_name);
  
  return $self->taxonomizer->fetch_taxon_id_by_name($species_name);
}
