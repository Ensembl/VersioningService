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

Bio::EnsEMBL::Versioning::Pipeline::Downloader::ArrayExpress - A class to download ArrayExpress's files

=head1 DESCRIPTION

This is a class which is used to download the ArrayExpress's files.
For more info about gene_info file, please refer: ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/atlas/bioentity_properties/ensembl/
Limiting to only ens(gene|protein|transcript).tsv files
=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::ArrayExpress;

use Moose;

extends 'Bio::EnsEMBL::Versioning::Pipeline::FTPDownloader';

sub BUILD {
  my $self = shift;
  $self->uri('ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/atlas/bioentity_properties/ensembl/');
  $self->file_pattern('\w+_\w+\.ens(gene|protein|transcript)\.tsv');
}

sub get_version {
  my $self = shift;
  return $self->timestamp;
}

__PACKAGE__->meta->make_immutable;

1;
