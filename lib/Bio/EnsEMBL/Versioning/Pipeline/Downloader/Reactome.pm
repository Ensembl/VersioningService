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

=cut

=head1 NAME

Bio::EnsEMBL::Versioning::Pipeline::Downloader::Reactome - A class to download Reactome's Ensembl2Reactome_All_Levels.txt and UniProt2Reactome_All_Levels.txt files

=head1 DESCRIPTION

This is a class which is used to download the Reactome's Ensembl2Reactome_All_Levels.txt and UniProt2Reactome_All_Levels.txt files
For more info about the files, please refer: please refer: http://www.reactome.org/download/mapping.README.txt
=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::Reactome;

use Moose;
use Try::Tiny;
use Bio::EnsEMBL::Versioning::Pipeline::Downloader::HTTPClient;

extends 'Bio::EnsEMBL::Versioning::Pipeline::Downloader';

has host => (
  isa => 'Str',
  is => 'ro',
  default => 'http://www.reactome.org',
);

has remote_path => (
  isa => 'Str', 
  is => 'ro',
  default => '/download/current/',
);


with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HTTPClient','MooseX::Log::Log4perl';

sub get_version
{
  my $self = shift;
  return $self->timestamp;
}

sub _get_remote {
  my $self = shift;
  my $path = shift; # path is already checked as valid.
  my $file_names = ['Ensembl2Reactome_All_Levels.txt', 'UniProt2Reactome_All_Levels.txt'];
  my $host_URL = $self->host.$self->remote_path;

  my $result = $self->get_http_files(
    host_URL => $self->host.$self->remote_path,
    filenames => $file_names,
    path => $path
  );
  $self->log->debug('Downloaded Reactome files: '.join("\n",@$result));
  return $result if (scalar @$result > 0);
  Bio::EnsEMBL::Mongoose::NetException->throw("No files downloaded from Reactome site");
}


__PACKAGE__->meta->make_immutable;

1;
