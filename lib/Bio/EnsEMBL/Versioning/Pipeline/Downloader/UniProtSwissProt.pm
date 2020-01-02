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

Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtSwissProt

=head1 DESCRIPTION

A module for Swissprot specific methods

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtSwissProt;

use Moose;
use Try::Tiny;

extends 'Bio::EnsEMBL::Versioning::Pipeline::FTPDownloader';
with 'MooseX::Log::Log4perl';

sub BUILD {
  my $self = shift;
  $self->uri('ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/');
  $self->file_pattern('uniprot_sprot.xml.gz');
  $self->version_uri('ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/relnotes.txt');
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
  if ($file =~ /UniProt Release (\d+_\d+)/m) {
    $version = $1;
  }
  Bio::EnsEMBL::Mongoose::NetException->throw('Failed to get version from UniProt release notes') unless $version;
  return $version;
}

__PACKAGE__->meta->make_immutable;

1;
