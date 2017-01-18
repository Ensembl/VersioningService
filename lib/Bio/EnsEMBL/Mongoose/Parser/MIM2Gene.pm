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

=cut

package Bio::EnsEMBL::Mongoose::Parser::MIM2Gene;
use Modern::Perl;
use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use Try::Tiny;
use Bio::EnsEMBL::Mongoose::IOException;
with 'Bio::EnsEMBL::Mongoose::Parser::Parser','MooseX::Log::Log4perl';

# consumes the mim2genefile.txt
# see also primary parser consuming omim.txt file
# MIM provides two different datasets in one download; morbidities and gene data
# This parser consumes the mim2gene file and extracts a few xrefs from it. 
# This file is superceded by mim2gene_medgen which restores the EntrezGene xrefs that disappeared from the main file
# Variation requires the disease information later on, but it does not play a part in Xrefs


sub read_record { 
  my $self = shift;

  $self->clear_record;
  $self->record->taxon_id(9606); # Mendelian inheritance in man after all.
  
  my $fh = $self->source_handle;
  my $content = <$fh>;
  return unless $content;
  until ($content !~ /^#/) { $content = <$fh> }
  # crudely skip over comment lines
  return unless $content;
  chomp($content);
  # MIM id, gene/phenotype/both, EntrezGene ID, gene symbol like ACR or ALDH2
  my ($id,$type,$entrezgene,$hgnc,$ensembl) = split "\t",$content; # trailing tabs mean all variables get set with '' at minimum
  Bio::EnsEMBL::Mongoose::IOException->throw ('Insufficient data in line of mim2gene:'.$content) unless ($id);
  $self->record->id($id);
  $self->record->accessions([$id]);
  if ($entrezgene) {
    $self->record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'EntrezGene',creator => 'MIM',id => $entrezgene));
  }
  if ($hgnc) {
    $self->record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'HGNC',creator => 'MIM',id => $hgnc));
  }
  if ($ensembl) {
    $self->record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'Ensembl',creator => 'MIM',id => $ensembl));
  }
  
  return 1;
}


__PACKAGE__->meta->make_immutable;
