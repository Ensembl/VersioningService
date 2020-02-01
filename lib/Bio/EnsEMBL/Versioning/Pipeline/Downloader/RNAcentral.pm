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

Bio::EnsEMBL::Versioning::Pipeline::Downloader::RNAcentral - A class to download RNAcentral's JSON Data file

=head1 DESCRIPTION

This is a class which is used to download the RNAcentral's json files.
For more info about the files, please refer: ftp://ftp.ebi.ac.uk/pub/databases/RNAcentral/current_release/release_notes.txt
=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::RNAcentral;

use Moose;
use Try::Tiny;
use Bio::EnsEMBL::Mongoose::NetException;

extends 'Bio::EnsEMBL::Versioning::Pipeline::FTPDownloader';

sub BUILD {
  my $self = shift;
  $self->uri('ftp://ftp.ebi.ac.uk/pub/databases/RNAcentral/current_release/json/');
  $self->file_pattern('ensembl-xrefs-\d+-\d+\.json');
  $self->version_uri('ftp://ftp.ebi.ac.uk/pub/databases/RNAcentral/current_release/release_notes.txt');
}

sub get_version
{
  my $self = shift;

  my $file;
  my $version;
  my $url = $self->version_uri();
  try {
    $file = $self->read_ftp_file($url);
  } catch {
    Bio::EnsEMBL::Mongoose::NetException->throw('Failed to retrieve version from '.$url);
  };

  #expected format: RNAcentral Release 7, 16/05/2017
  if ($file =~ /RNACentral Release (\d+), \d{1,2}\/\d{1,2}\/\d{4}/gi) {
    $version = $1;
  }
  Bio::EnsEMBL::Mongoose::NetException->throw('Failed to get version from RNACentral release notes') unless $version;
  return $version;
}


__PACKAGE__->meta->make_immutable;

1;
