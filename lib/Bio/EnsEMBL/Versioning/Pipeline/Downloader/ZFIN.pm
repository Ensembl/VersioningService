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

Bio::EnsEMBL::Versioning::Pipeline::Downloader::ZFIN - A class to download ZFIN gene names

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::ZFIN;

use Moose;
use Try::Tiny;
use Bio::EnsEMBL::Versioning::Pipeline::Downloader::HTTPClient;

extends 'Bio::EnsEMBL::Versioning::Pipeline::Downloader';

has host => (
  isa => 'Str',
  is => 'ro',
  default => 'http://www.zfin.org',
);

has remote_path => (
  isa => 'Str', 
  is => 'ro',
  default => '/downloads/',
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
  my $file_names = ['uniprot.txt', 'refseq.txt', 'aliases.txt'];
  my $host_URL = $self->host.$self->remote_path;

  my $result = $self->get_http_files(
    host_URL => $self->host.$self->remote_path,
    filenames => $file_names,
    path => $path
  );
  $self->log->debug('Downloaded ZFIN files: '.join("\n",@$result));
  return $result if (scalar @$result > 0);
  Bio::EnsEMBL::Mongoose::NetException->throw("No files downloaded from ".$self->host.$self->remote_path);
}


__PACKAGE__->meta->make_immutable;

1;
