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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Versioning::Pipeline::JobPerFile

=head1 DESCRIPTION

Given a folder full of files, generate a fan of one job per file
Also potentially branch to alternative resource classes for unusually sized jobs

=cut

package Bio::EnsEMBL::Versioning::Pipeline::JobPerFile;

use strict;
use warnings;
use Bio::EnsEMBL::Versioning::Broker;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

sub run {
  my ($self) = @_;
  my $version = $self->param_required('version');
  my $source_name = $self->param_required('source_name');
  my $broker = $self->configure_broker_from_pipeline();
  my $unindexed_version = $broker->get_version_of_source($source_name,$version);
  my $file_list = $broker->get_file_list_for_version($unindexed_version);
  # This is where we can choose a different parse process to do more efficient resource management
  foreach my $file (@$file_list) {
    my $message = { source_name => $source_name , version => $unindexed_version, file => $file};
    $self->dataflow_output_id($message, 2);
    $self->dataflow_output_id({source => $source_name, version => $version}, 1);
  }
  return;
}



1;
