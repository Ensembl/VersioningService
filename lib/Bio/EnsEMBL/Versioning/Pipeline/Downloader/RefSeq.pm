=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq

=head1 DESCRIPTION

A module for RefSeq specific downloading methods

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq;

use Moose;

extends 'Bio::EnsEMBL::Versioning::Pipeline::Downloader';

has uri => (
  isa => 'Str', 
  is => 'ro',
  default => 'ftp://ftp.ncbi.nlm.nih.gov/refseq/release/complete/',
);

has file_pattern => (
  isa => 'Str',
  is => 'rw', # to allow test runs
  default => 'complete\.\d+(\.\d+)?\.(protein|rna)\.g[bp]ff.gz',
);

has version_uri => ( 
  isa => 'Str', 
  is => 'ro', 
  default => 'ftp://ftp.ncbi.nlm.nih.gov/refseq/release/release-notes/',
);

with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::FTPClient';
with 'MooseX::Log::Log4perl';

sub get_version
{
  my $self = shift;
  my $file_list = $self->ls_ftp_dir($self->version_uri);
  $self->log->debug('Checked Refseq FTP version folder, found '.join(',',@$file_list));
  my $version;
  while (my $file = shift @$file_list) {
    if ($file =~ /RefSeq-release(\d+)/) {
      $version = $1;
      return $version;
    }
  }
  Bio::EnsEMBL::Mongoose::NetException->throw("Version not found");
}

sub _get_remote {
  my $self = shift;
  my $path = shift; # path is already checked as valid.

  my $result = $self->get_ftp_files($self->uri,$self->file_pattern,$path);
  $self->log->debug('Downloaded Refseq FTP files: '.join("\n",@$result));
  return $result if (scalar @$result > 0);
  Bio::EnsEMBL::Mongoose::NetException->throw("No files downloaded from RefSeq source");
}

1;
