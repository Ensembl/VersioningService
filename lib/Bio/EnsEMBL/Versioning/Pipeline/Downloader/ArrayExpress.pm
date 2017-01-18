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

=head1 NAME

Bio::EnsEMBL::Versioning::Pipeline::Downloader::ArrayExpress - A class to download ArrayExpress's files

=head1 DESCRIPTION

This is a class which is used to download the ArrayExpress's files.
For more info about gene_info file, please refer: ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/atlas/bioentity_properties/ensembl/
Limiting to only ens(gene|protein|transcript).tsv files
=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::ArrayExpress;

use Moose;
use Try::Tiny;

extends 'Bio::EnsEMBL::Versioning::Pipeline::Downloader';

has uri => (
  isa => 'Str', 
  is => 'ro',
  default => 'ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/atlas/bioentity_properties/ensembl/',
);

has file_pattern => (
  isa => 'Str',
  is => 'rw', # to allow test runs
  default => '\w+_\w+\.ens(gene|protein|transcript)\.tsv'
  
);

with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::FTPClient','MooseX::Log::Log4perl';

sub get_version
{
  my $self = shift;
  return $self->timestamp;
}

sub _get_remote {
  my $self = shift;
  my $path = shift; # path is already checked as valid.

  my $result = $self->get_ftp_files($self->uri,$self->file_pattern,$path);
  $self->log->debug('Downloaded ArrayExpress FTP files: '.join("\n",@$result));
  return $result if (scalar @$result > 0);
  Bio::EnsEMBL::Mongoose::NetException->throw("No files downloaded from ArrayExpress source");
}

__PACKAGE__->meta->make_immutable;

1;
