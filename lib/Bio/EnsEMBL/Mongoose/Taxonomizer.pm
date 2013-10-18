use Moose;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Config::General;

has dba => (
    isa => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    is => 'ro',
    required => 1,
    builder => 'load_compara_db',
    
);

has config => (
    isa => 'HashRef',
    is => 'ro',
    required => 1,
    default => sub {
        my $self = shift;
        my $conf = Config::General->new($self->config_file);
        my %opts = $conf->getall();
        return \%opts;
    },
);

sub load_compara_db {
    
}