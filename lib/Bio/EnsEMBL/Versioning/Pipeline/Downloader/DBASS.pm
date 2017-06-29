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

=head1 NAME

Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS

=head1 DESCRIPTION

A module for DBASS data specific downloading methods

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS;

use Moose;

extends 'Bio::EnsEMBL::Versioning::Pipeline::RESTDownloader';

sub BUILD {
  my $self = shift;
  $self->host('http://www.dbass.soton.ac.uk/');
  $self->remote_path('dbass5/download.aspx?item=genes');
  $self->file_pattern('xref.php');
  $self->file_name('dbass.csv');
}

sub get_version
{
  my $self = shift;
  return $self->timestamp; 
}


__PACKAGE__->meta->make_immutable;

1;
