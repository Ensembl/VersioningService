package Bio::EnsEMBL::Versioning::DB;

use strict;
use warnings;

use base qw(Rose::DB);

__PACKAGE__->use_private_registry;      ## Use a private registry for this class
__PACKAGE__->default_domain('ensembl'); ## Set the default domain

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
    server_time_zone => 'UTC',
  );
  return;
}


1;
