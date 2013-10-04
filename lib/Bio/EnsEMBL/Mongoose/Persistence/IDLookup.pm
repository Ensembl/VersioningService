package Bio::EnsEMBL::Mongoose::Persistence::IDLookup;

use Moose;

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use FindBin qw/$Bin/;

Log::Log4perl::init("$Bin/../conf/logger.conf");

has lucy => (
    is => 'ro',
    isa => 'Bio::EnsEMBL::Mongoose::Persistence::LucyQuery',
    default => sub {
        return my $lucy = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config_file => "$Bin/../conf/swissprot.conf");
    }
);

# NOTE - only exists to satisfy one-time Uniparc lookup. It assumes one Uniprot ID 
# per record, and ignores possible primary accessions
sub fetch_id {
    my $self = shift;
    my $ens_id = shift;
    
    my $query = 'xref:'.$ens_id;
    
    $self->lucy->query($query);
    
    my $hit = $self->lucy->next_result;
    return $hit->{accessions};
}