=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Versioning::Pipeline::Base

=head1 DESCRIPTION

Base class containing common functions for the versioning Pipeline

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Base;

use strict;
use warnings;

# use Bio::EnsEMBL::Mongoose::UsageException;
# use Try::Tiny;
# use Class::Inspector;

use parent qw/Bio::EnsEMBL::Hive::Process/;

# sub get_module {
#   my $self = shift;
#   my $name = shift;

#   try {
#     (my $file = $name) =~ s|::|/|g;
#     if (!(Class::Inspector->loaded($name))) {
#       require $file . '.pm';
#       $name->import();
#     }
#     return $name;
#   } catch {
#     Bio::EnsEMBL::Mongoose::UsageException->throw("Module $name could not be found. $_");
#   };
# }

1;