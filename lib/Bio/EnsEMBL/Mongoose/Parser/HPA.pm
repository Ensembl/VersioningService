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

Bio::EnsEMBL::Mongoose::Parser::HPA - A class to parse a simple CSV file
downloade from the Human Protein Atlas (HPA) database.

=head1 DESCRIPTION

The database contains two types of antibody, their own HPA antibodies and 
Collaborator antibody (CAB) commercial antibodies. 
The columns of the file should be the following:

1) Antibody
2) Antibody ID
3) Ensembl Peptide ID
4) Link (URL)

=cut

package Bio::EnsEMBL::Mongoose::Parser::HPA;

use Moose;

use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

with 'Bio::EnsEMBL::Mongoose::Parser::Parser', 'MooseX::Log::Log4perl';

sub read_record {
  my $self = shift;
  $self->clear_record;
  my $record  = $self->record;
  $record->taxon_id(9606); # this is HUMAN protein atlas
  
  my $fh = $self->source_handle;
  my $content = <$fh>;
  return unless $content; # skip if empty record
    
  # if header advance to next record
  if ($content =~ /^Antibody,antibody_id/) {
    $content = <$fh>;
    return unless $content;
  }

  chomp($content);
  $content =~ s/\s*$//;
  my ($antibody, $antibody_id, $ensembl_peptide_id, $link) = split /,/, $content;
  Bio::EnsEMBL::Mongoose::IOException->throw ('Insufficient data in HPA line: ' . $content)
      unless $antibody and $antibody_id and $ensembl_peptide_id;
  Bio::EnsEMBL::Mongoose::IOException->throw ("Wrong Ensembl peptide ID in HPA line: $ensembl_peptide_id")
      if $ensembl_peptide_id !~ /^ENSP0{5}[0-9]{6}/;

  $record->id($antibody_id);
  $record->display_label($antibody);
  $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'ensembl_protein', creator => 'HPA', id => $ensembl_peptide_id));

  return 1;
}

__PACKAGE__->meta->make_immutable;
