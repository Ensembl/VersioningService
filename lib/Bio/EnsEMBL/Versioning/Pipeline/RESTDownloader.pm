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

package Bio::EnsEMBL::Versioning::Pipeline::RESTDownloader;

use Moose;
use Bio::EnsEMBL::Mongoose::NetException;
extends 'Bio::EnsEMBL::Versioning::Pipeline::Downloader';
with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RESTClient','MooseX::Log::Log4perl';

has host => (
  isa => 'Str',
  is => 'rw',
);

has remote_path => (
  isa => 'Str', 
  is => 'rw',
);

has file_pattern => (
  isa => 'Str',
  is => 'rw', # to allow test runs
);

has accepts => (
  isa => 'Str',
  is => 'rw',
  default => 'text/plain'
);

has file_name => (
  isa => 'Str',
  is => 'rw'
);

sub _get_remote {
  my $self = shift;
  my $path = shift; # path is already checked as valid.

  my $result = $self->call(
    host => $self->host,
    path => $self->remote_path . $self->file_pattern,
    file_path => $path,
    accepts => $self->accepts,
    file_name => $self->file_name,
    retry_delay => 30
  );
  
  $self->log->debug('Downloaded file: ' . join("\n", @$result));

  return $result if (scalar @$result > 0);

  Bio::EnsEMBL::Mongoose::NetException->throw("No files downloaded from site: ".$self->host.$self->remote_path);
}

__PACKAGE__->meta->make_immutable;

1;