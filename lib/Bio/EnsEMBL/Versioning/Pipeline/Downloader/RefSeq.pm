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

Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq

=head1 DESCRIPTION

A module for RefSeq specific downloading methods

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq;

use Moose;
use Try::Tiny;
use Bio::EnsEMBL::Mongoose::NetException;

extends 'Bio::EnsEMBL::Versioning::Pipeline::FTPDownloader';
with 'MooseX::Log::Log4perl';

sub BUILD {
  my $self = shift;
  $self->uri('ftp://ftp.ncbi.nlm.nih.gov/refseq/release/complete/');
  $self->file_pattern('complete\.\d+(\.\d+)?\.(protein|rna)\.g[bp]ff.gz');
  $self->version_uri('ftp://ftp.ncbi.nlm.nih.gov/refseq/release/release-notes/');
}

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

__PACKAGE__->meta->make_immutable;

1;
