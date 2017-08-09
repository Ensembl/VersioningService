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

Bio::EnsEMBL::Versioning::Pipeline::CollateIndexes

=head1 DESCRIPTION

Once all parsing jobs for one source have completed, finalise the index in the Versioning Service

=cut

package Bio::EnsEMBL::Versioning::Pipeline::CollateIndexes;

use strict;
use warnings;
use Bio::EnsEMBL::Versioning::Broker;

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

sub run {
  my ($self) = @_;
  my $broker = $self->configure_broker_from_pipeline();
  my $source_name = $self->param_required('source_name');
  my $version = $self->param_required('version');

  # Semaphore released means this job can infer the parse jobs for this source were all successful
  # Therefore we can set the new latest version for the source
  
  my $latest_version = $broker->get_version_of_source($source_name,$version);
  $broker->set_current_version_of_source( $source_name, $latest_version->revision);
  
  return;
}



1;
