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

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Bio::EnsEMBL::Versioning::TestDB;

use Bio::EnsEMBL::Versioning::Broker;
use Env;
require Exporter;
use parent 'Exporter';
@EXPORT_OK = qw(broker);

my $broker = Bio::EnsEMBL::Versioning::Broker->new(config_file => get_conf_location(), create => 1);
# $broker->schema->deploy(); # auto create schema in test DB

sub get_conf_location {
  my $conf = $ENV{MONGOOSE_TEST}; # MONGOOSE_TEST defines the config file to use for this test. e.g. working with a different DB engine.
  $conf ||= $ENV{MONGOOSE}.'/conf/test.conf';
  return $conf;
}

sub broker {
  return $broker;
}

# Insert cleanup of test database depending on driver here, or get Test::DBIx::Class configured before it is used.
# DESTROY {
#   $broker->schema->

# }


1;
