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

Bio::EnsEMBL::Versioning::Pipeline::CheckLatest

=head1 DESCRIPTION

A module which checks what the latest version of a source is on the server, and if it is the same as the one locally held


=cut

package Bio::EnsEMBL::Versioning::Pipeline::CheckLatest;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::DB;
use Bio::EnsEMBL::Versioning::Broker;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

sub run {
  my ($self) = @_;
  my $source_name = $self->param_required('source_name');
  my $broker = Bio::EnsEMBL::Versioning::Broker->new();
  my $local_version = $broker->get_current_version_of_source($source_name);
  my $downloader = $broker->get_module($source->downloader)->new;
  my $remote_version = $downloader->get_version;
  my $local_revision;
  if (defined $local_version) {$local_revision = $local_version->revision}
  else {$local_revision = ''}
  my $input_id;
  if (!defined $remote_version) {
    $input_id = {
      error => "Version could not be found for $source_name",
      source_name => $source_name
    };
    $self->dataflow_output_id($input_id, 4);
    return;
  }
  if ($remote_version ne $local_revision) {
    $input_id = {
      source_name => $source_name,
      version => $remote_version,
    };
    $self->warning(sprintf('Flowing %s with %s to %d for %s', $source_name, $remote_version, 2, 'updater pipeline'));
    $self->dataflow_output_id($input_id, 2);
  } else {
    $self->warning(sprintf('Source %s left at version %s', $source_name, $local_revision));
  }
}

1;
