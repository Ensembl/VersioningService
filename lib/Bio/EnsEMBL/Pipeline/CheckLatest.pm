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

Bio::EnsEMBL::Pipeline::CheckLatest

=head1 DESCRIPTION

A module which checks what the latest version of a source is on the server, and if it is the same as the one locally held

Allowed parameters are:

=over 8

=cut

package Bio::EnsEMBL::Pipeline::CheckLatest;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::DB;
use Bio::EnsEMBL::Versioning::Manager::Resources;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Class::Inspector;

use base qw/Bio::EnsEMBL::Pipeline::Base/;

sub run {
  my ($self) = @_;
  my $version = $self->param('version');
  my $source_name = $self->param('source_name');
  my $latest_version = $self->get_version($source_name);
  if ($version ne $latest_version) {
    my $input_id = {
      version => $latest_version,
      source_name => $source_name
    };
    $self->dataflow_output_id($input_id, 3);
  }
}

sub get_version {
  my $self = shift;
  my $source_name = shift;
  my $resource_manager = 'Bio::EnsEMBL::Versioning::Manager::Resources';
  my $resource = $resource_manager->get_release_resource($source_name);
  my $release_file = $resource->value();
  my $type = $resource->type();
  my $version;
  if ($type eq 'ftp') {
    $version = $self->get_ftp_version($resource);
  }
  return $version;
}


sub get_ftp_version {
  my $self = shift;
  my $resource = shift;
  my $file = $self->get_ftp_file($resource->value);
  my $name = $resource->source->name();
  my $module = $self->get_module($name);
  my $version = $module->get_version($file);
  return $version;
}

sub get_module {
  my $self = shift;
  my $name = shift;

  my $prefix = 'Bio::EnsEMBL::Pipeline::';
  my $module = $prefix . $name;

  eval {
    (my $file = $module) =~ s|::|/|g;
    if (!(Class::Inspector->loaded($module))) {
      require $file . '.pm';
      $module->import();
    }
    return $module;
  } or do {
    throw("Module $module could not be found");
  };
}

1;
