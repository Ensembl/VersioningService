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

Bio::EnsEMBL::Mongoose::Parser::Xenbase - A class to parse xenopus tropicalis
data from Xenbase source.

=head1 DESCRIPTION

This is a parser for Xenopus tropicalis data from Xenbase. The source is a
tab separated file with the following fields:

1. gene id
2. gene name
3. description
4. ensembl gene id

=cut

package Bio::EnsEMBL::Mongoose::Parser::Xenbase;

use Moose;

use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

with 'Bio::EnsEMBL::Mongoose::Parser::Parser', 'MooseX::Log::Log4perl';

sub read_record {
  my $self = shift;
  $self->clear_record;
  my $record  = $self->record;
  $record->taxon_id(8364); # this is Xenopus tropicalis
  
  my $fh = $self->source_handle;
  my $content = <$fh>;
  return unless $content; # skip if empty record
    
  chomp($content);
  my ($acc, $label, $desc, $ensembl_id) = split /\t/, $content;
  Bio::EnsEMBL::Mongoose::IOException->throw ('Insufficient data in Xenbase line: ' . $content)
      unless $acc and $label and $desc and $ensembl_id;

  $record->id($acc);
  $record->display_label($label);
  $record->gene_name($label); 
  $record->description($desc);

  $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'Ensembl', creator => 'Xenbase', id => $ensembl_id));
  
  return 1;
}

__PACKAGE__->meta->make_immutable;
