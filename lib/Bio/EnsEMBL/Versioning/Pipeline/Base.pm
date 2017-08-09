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

Bio::EnsEMBL::Versioning::Pipeline::Base

=head1 DESCRIPTION

Base class containing common functions for the versioning Pipeline

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Base;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Broker;
# use Bio::EnsEMBL::Mongoose::UsageException;
# use Try::Tiny;
# use Class::Inspector;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;


# The broker self-configures from a default file, but these can be overridden with values at instantiation
sub configure_broker_from_pipeline {
  my $self = shift;
  
  my %conf; # For direct setting of properties from pipeline rather than config file.
  # Extend here to import more options from pipeline input
  my $options_set = 0;
  for my $var_name (qw/config_file scratch_space type driver db file host user pass port create/) {
    if ($self->param_is_defined($var_name)) {
      my $temp = $self->param($var_name);
      if (defined $temp) {
        $conf{$var_name} = $temp;
        $options_set = 1;
      }
    }
  }
  
  my $broker;
  if ($options_set) {
    $broker = Bio::EnsEMBL::Versioning::Broker->new(config => \%conf);
  } else {
    $broker = Bio::EnsEMBL::Versioning::Broker->new();
  }

  return $broker;
}

1;
