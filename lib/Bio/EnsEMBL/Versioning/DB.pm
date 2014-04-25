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

package Bio::EnsEMBL::Versioning::DB;

use strict;
use warnings;

# use parent qw(Rose::DB);
use parent qw(Rose::DBx::AutoReconnect);

__PACKAGE__->use_private_registry;      ## Use a private registry for this class
__PACKAGE__->default_domain('ensembl'); ## Set the default domain

__PACKAGE__->register_db(
      domain   => 'ensembl',
      type     => 'default',
      driver   => 'mysql',
    );

sub register_DBAdaptor {
  my $self = shift;
  my $db_adaptor = shift;
  my $dbc = $db_adaptor->dbc();
  $self->register_db(
    domain   => 'ensembl',
    type     => 'default',
    driver   => $dbc->driver,
    database => $dbc->dbname,
    host     => $dbc->host,
    username => $dbc->username,
    password => $dbc->password,
    port     => $dbc->port,
    server_time_zone => 'UTC',
  );
  return;
}


1;
