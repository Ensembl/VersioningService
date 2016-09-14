=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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
Can bypass the download stage if there is nothing to download and we already have a version that isn't parsed.

=cut

package Bio::EnsEMBL::Versioning::Pipeline::CheckLatest;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Broker;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;
use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

sub run {
  my ($self) = @_;
  my $source_name = $self->param_required('source_name');
  my $broker = Bio::EnsEMBL::Versioning::Broker->new();
  my $local_version = $broker->get_current_version_of_source($source_name);
  my $downloader;
  if ($local_version) {
    $downloader = $broker->get_module($local_version->sources->downloader)->new;
  } else {
    $downloader = $broker->get_module($broker->get_downloader($source_name))->new;
  }
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
    $self->warn("Version could not be found for $source_name");
    return;
  }
  if ($remote_version ne $local_revision) {
    $input_id = {
      source_name => $source_name,
      version => $remote_version,
    };
    $self->warning(sprintf('Flowing %s with %s to %s for %s', $source_name, $remote_version, 'downloading', 'updater pipeline'));
    $self->dataflow_output_id($input_id, 2);
  } else {
    $broker->already_seen($local_version);
    # This source may not have an index, but the download already took place and there is no newer file to download
    # Therefore skip download and try again to parse the existing download
    if (! defined $local_version->index_uri) {
      $self->warning(sprintf('Flowing %s with %s to %s for %s. No download required', $source_name, $local_version, 'parsing', 'updater pipeline'));
      $self->dataflow_output_id({ source_name => $source_name, version => $local_version }  ,3);
    }
    $self->warning(sprintf('Source %s left at version %s', $source_name, $local_revision));
  }
}

1;
