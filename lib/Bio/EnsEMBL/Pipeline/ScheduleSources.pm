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

Bio::EnsEMBL::Pipeline::ScheduleSources

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

package Bio::EnsEMBL::Pipeline::ScheduleSources;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;
use Bio::EnsEMBL::Utils::Scalar qw/check_ref/;
use Bio::EnsEMBL::Versioning::DB;
use Bio::EnsEMBL::Versioning::Manager::Source;
use POSIX qw/strftime/;

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

sub param_defaults {
  my ($self) = @_;
  return {
    sources => []
  };
}

sub fetch_input {
  my ($self) = @_;
  
  my $versioning_db = $self->get_versioning_db();
  my $source_manager = 'Bio::EnsEMBL::Versioning::Manager::Source';
  my $sources = $source_manager->get_sources();
  $self->info('Found %d sources(s) to process', scalar(@{$sources}));
  $self->param('sources', $sources);
  
  return;
}
  
sub run {
  my ($self) = @_;
  my @sources;
  foreach my $source (@{$self->param('sources')}) {
    my $input_id = $self->input_id($source);
    push(@sources, [ $input_id, 2 ]);
  }
  $self->param('sources', \@sources);
  return;
}

sub write_output {
  my ($self) = @_;
  $self->do_flow('sources');
  return;
}

sub do_flow {
  my ($self, $key) = @_;
  my $targets = $self->param($key);
  foreach my $entry (@{$targets}) {
    my ($input_id, $flow) = @{$entry};
    $self->fine('Flowing %s to %d for %s', $input_id->{source_name}, $flow, $key);
    $self->dataflow_output_id($input_id, $flow);
  }
  return;
}

sub input_id {
  my ($self, $source) = @_;
  my $source_manager = 'Bio::EnsEMBL::Versioning::Manager::Source';
  my $input_id = {
    version => $source_manager->get_current($source->name())->version(),
    source_name => $source->name(),
  };
  return $input_id;
}

sub db_types {
  my ($self, $dba) = @_;
  return $self->param('db_types');
}

sub get_versioning_db {
  my ($self) = @_;
  return Bio::EnsEMBL::Versioning::DB->new();
}

1;
