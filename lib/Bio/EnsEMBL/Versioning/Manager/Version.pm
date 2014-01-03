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

package Bio::EnsEMBL::Versioning::Manager::Version;

use strict;
use warnings;
use Carp;

use Bio::EnsEMBL::Versioning::Object::Version;
use base qw(Bio::EnsEMBL::Versioning::Manager);


sub object_class { 'Bio::EnsEMBL::Versioning::Object::Version' }

 __PACKAGE__->make_manager_methods('versions');


=head2 get_all_versions

    Arg [0]     : String; the name of the source
    Description : Returns all the available version for a given source
    Returntype  : Listref of Bio::EnsEMBL::Versioning::Version objects
    Exceptions  : die if no source name given or source name not found
    Caller      : general

=cut

sub get_all_versions {
  my $self = shift;
  my $source_name = shift;
  croak("No source_name given") if !$source_name;

  my %versions;
  my $versions = $self->get_objects(
                         with_objects => ['source'],
                         query => [
                                   'source.name' => $source_name
                                  ],
                         distinct => 1);
  croak("No versions found for $source_name") if !$versions->[0];

  return $versions;
}

=head2 get_current

    Arg [0]     : String; the name of the source
    Description : Returns the current version of a source
    Returntype  : Bio::EnsEMBL::Versioning::Version
    Exceptions  : die if no source name given or source name not found
    Caller      : general

=cut

sub get_current {
  my $self = shift;
  my $source_name = shift;
  croak("No source_name given") if !$source_name;

  my %versions;
  my $versions = $self->get_objects(
                         with_objects => ['source'],
                         query => [
                                   'source.name' => $source_name,
                                   is_current => 1
                                  ],
                         distinct => 1);
  croak("No versions found for $source_name") if !$versions->[0];

  return $versions->[0];
}



1;
