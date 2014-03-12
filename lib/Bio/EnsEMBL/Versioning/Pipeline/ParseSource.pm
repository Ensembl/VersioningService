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

Bio::EnsEMBL::Pipeline::ParseSource

=head1 DESCRIPTION

eHive pipeline module for the consumption of a downloaded resource into a document store

=cut

package Bio::EnsEMBL::Pipeline::ParseSource;

use strict;
use warnings;




sub run {
  my ($self) = @_;
  my $source_name = $self->param('source_name');
  my $resource = Bio::EnsEMBL::Versioning::Manager::Resources->get_release_resource($source_name);
# Get parser from Source object
  my $source = Bio::EnsEMBL::Versioning::Manager::Source->get_sources(query => [ name => $source_name ]);
  

}

sub get_destination_path {
  
}

sub get_source_path {
  
}

sub parse_file {
  
}

1;