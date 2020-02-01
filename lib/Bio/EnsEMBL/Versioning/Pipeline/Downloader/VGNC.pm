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

=cut

=head1 NAME

Bio::EnsEMBL::Versioning::Pipeline::Downloader::VGNC - A class to download VGNC data

=head1 DESCRIPTION

This is a class which is used to download the VGNC file located at ftp://ftp.ebi.ac.uk/pub/databases/genenames/vgnc/tsv/chimpanzee/chimpanzee_vgnc_gene_set_All.txt

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::VGNC;

use Moose;

extends 'Bio::EnsEMBL::Versioning::Pipeline::FTPDownloader';

sub BUILD {
  my $self = shift;
  $self->uri('ftp://ftp.ebi.ac.uk/pub/databases/genenames/vgnc/tsv/');
  $self->file_pattern('vgnc_gene_set_All.txt.gz');
}
# Version is a timestamp of now
sub get_version {
  my $self = shift;
  return $self->timestamp;
}

__PACKAGE__->meta->make_immutable;

1;
