=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Mongoose::Parser::RGD - A class to parse rat gene data available
from the Rat Genome Database

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Mongoose::Parser::RGD;

use Moose;

use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

with 'Bio::EnsEMBL::Mongoose::Parser::Parser', 'MooseX::Log::Log4perl';

sub read_record {
  my $self = shift;
  $self->clear_record;
  my $record  = $self->record;
  $record->taxon_id(10116); # this is rattus norvegicus
  
  my $fh = $self->source_handle;
  my $content = <$fh>;
  return unless $content; # skip if empty record
    
  # if comment advance to first available record
  if ($content =~ /^#/) {
    while ($content =~ /^#/) {
      $content = <$fh>;
    }
    $content = <$fh>;
    return unless $content;
  }

  chomp($content);
  my ($rgd, $symbol, $name, $refseq, $old_name, $ensembl_id) = (split /\t/, $content)[0, 1, 2, 23, 29, 37];
  Bio::EnsEMBL::Mongoose::IOException->throw ('Insufficient data in RGD line: ' . $content)
      unless $rgd and $symbol and $name;

  $record->id($rgd); # RGD gene ID
  $record->display_label($symbol); # official gene symbol
  $record->entry_name($symbol); # which is also the gene name
  $record->description($name); # gene name is sufficiently verbose to appear as a description
  $record->add_synonym(split /;/, $old_name) if $old_name; # old name alias(es)

  # RGD maintains links from each of their gene IDs to GenBank nucleotide IDs, separated by ';'
  map { $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'RefSeq', creator => 'RGD', id => $_)) }
    split /;/, $refseq if $refseq;
  # the same for Ensembl Gene IDs
  map { $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'Ensembl', creator => 'RGD', id => $_)) }
    split /;/, $ensembl_id if $ensembl_id;
  
  return 1;
}

__PACKAGE__->meta->make_immutable;
