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

Bio::EnsEMBL::Versioning::Pipeline::ScheduleSources

=head1 DESCRIPTION

A module which generates update jobs for each source where the latest version is not up-to-date

Allowed parameters are:

=over 8

=item sources   - Can be an array of sources to update
                If specified only jobs will be created for
                those sources. Defaults to nothing so all sources are processed

=back

The code flows once per source to branch 2.

=cut

package Bio::EnsEMBL::Versioning::Pipeline::ScheduleSources;

use strict;
use warnings;
use Bio::EnsEMBL::Versioning::Broker;
use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

sub param_defaults {
  my ($self) = @_;
  return {
    sources => []
  };
}

sub fetch_input {
  my ($self) = @_;
  my $broker = Bio::EnsEMBL::Versioning::Broker->new;
  my $sources = $broker->get_active_sources;
  $self->warning(sprintf 'Found %d active sources(s) to process', scalar(@{$sources}));
  $self->param('sources', $sources);
  return;
}
  
sub run {
  my ($self) = @_;
  return;
}

sub write_output {
  my ($self) = @_;
  my $sources = $self->param('sources');
  my $flow = 2;
  foreach my $source (@{$sources}) {
    $self->dataflow_output_id({'source_name' => $source->name},$flow);
  }
  return;
}

1;
