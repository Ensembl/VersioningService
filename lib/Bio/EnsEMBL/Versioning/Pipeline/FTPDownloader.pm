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

# FTP-specialised class

package Bio::EnsEMBL::Versioning::Pipeline::FTPDownloader;

use Moose;
extends 'Bio::EnsEMBL::Versioning::Pipeline::Downloader';
with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::FTPClient','MooseX::Log::Log4perl';

has uri => (
  isa => 'Str', 
  is => 'rw'
);

has file_pattern => (
  isa => 'Str',
  is => 'rw'
);

has version_uri => (
  isa => 'Str',
  is => 'rw'
);

# A useful default _get_remote implementation
sub _get_remote {
  my $self = shift;
  my $path = shift; # path is already checked as valid.

  my $result = $self->get_ftp_files($self->uri,$self->file_pattern,$path);
  $self->log->debug(sprintf 'Downloaded %s FTP files: %s', $self->meta->name , join("\n", @$result));
  return $result if (scalar @$result > 0);
  
  Bio::EnsEMBL::Mongoose::NetException->throw("No files downloaded from source ".$self->meta->name);
}

__PACKAGE__->meta->make_immutable;
1;