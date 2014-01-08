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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Pipeline::DownloadSource

=head1 DESCRIPTION

A module which downloads a given source and saves it as a file

Allowed parameters are:

=over 8

=cut

package Bio::EnsEMBL::Pipeline::DownloadSource;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Manager::Resources;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use URI;
use File::Basename;
use Class::Inspector;

use base qw/Bio::EnsEMBL::Pipeline::Base/;

sub run {
  my ($self) = @_;
  my $latest_version = $self->param('version');
  my $source_name = $self->param('source_name');
  my $dir = $self->param('download_dir');
  my $resource_manager = 'Bio::EnsEMBL::Versioning::Manager::Resources';
  my $resource = $resource_manager->get_download_resource($source_name);
  my $filename = $dir . '/' . $source_name . '/' . $latest_version;
  my $value = $resource->value();
  system("mkdir -p $filename");
  my $type = $resource->type();
  my $result;
  if ($type eq 'ftp') {
    $result = $self->get_ftp_file($resource, $filename);
  }
  if (!$result) {
    my $input_id = {
      error => "File could not be downloaded for $value",
      source_name => $source_name
    };
    $self->fine('Flowing %s with %s to %d for %s', $source_name, $value, 4, 'download failed');
    $self->dataflow_output_id($input_id, 4);
    return;
  }
}



1;
