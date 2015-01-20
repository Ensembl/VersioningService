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

Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM

=head1 DESCRIPTION

A module for OMIM specific downloading methods

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM;

use Moose;
use Try::Tiny;

extends 'Bio::EnsEMBL::Versioning::Pipeline::Downloader';

has uri => (
  isa => 'Str', 
  is => 'ro',
  default => 'ftp://ftp.omim.org/OMIM/',
);

has file_pattern => (
  isa => 'Str',
  is => 'rw', # to allow test runs
  default => 'omim.txt.Z',
);

has version_uri => ( 
  isa => 'Str', 
  is => 'ro', 
  default => 'ftp://ftp.omim.org/OMIM/',
);

has password => (
  isa => 'Str',
  is => 'rw',
  default => 'anonymous'
);

has user => (
  isa => 'Str',
  is => 'rw',
  default => 'anonymous',
);

with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::FTPClient';
with 'MooseX::Log::Log4perl';

sub get_version
{
  my $self = shift;
  my $time = $self->get_timestamp($self->version_uri,'omim.txt.Z',$self->user,$self->password);
  $self->log->debug('Checked OMIM modification date, found '.$time);
  return $time if $time;
  Bio::EnsEMBL::Mongoose::NetException->throw("OMIM modification date not found");
}

sub _get_remote {
  my $self = shift;
  my $path = shift; # path is already checked as valid.

  my $result = $self->get_ftp_files($self->uri,$self->file_pattern,$path,$self->user,$self->password);
  $self->log->debug('Downloaded MIM FTP files: '.join("\n",@$result));
  return $result if (scalar @$result > 0);
  Bio::EnsEMBL::Mongoose::NetException->throw("No files downloaded from MIM site");
}

__PACKAGE__->meta->make_immutable;

1;
