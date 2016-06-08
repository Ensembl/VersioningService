use strict;
use warnings;

use Log::Log4perl;
use Time::HiRes qw(gettimeofday tv_interval);
my $data_location = shift;
$data_location ||= '/gpfs/nobackup/ensembl/ktaylor/uniprot_trembl.xml.gz';

my $index_location = shift;
$index_location ||= '/gpfs/nobackup/ensembl/ktaylor/index/';


Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster;
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;
#use Bio::EnsEMBL::Mongoose::Persistence::FlatFileFeeder;

my $parser = Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster->new( source_file => $data_location );
my $doc_store = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new( index => $index_location);
#my $doc_store = Bio::EnsEMBL::Mongoose::Persistence::FlatFileFeeder->new( index => $opts{index_location});
my $buffer = 0;
my $logger = Log::Log4perl->get_logger();

$logger->info("Beginning to parse ".$data_location);

while ($parser->read_record) {
    my $start_time = [gettimeofday];
    my $record = $parser->record;
    $doc_store->store_record($record);
    $buffer++;
    if ($buffer % 100000 == 0) {
        $doc_store->commit;
        $doc_store = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new( index => $index_location);
        my $interval = tv_interval($start_time, [gettimeofday]);
        printf "%.2f records per second\n",100000/$interval;
    }
};

$doc_store->commit;
$logger->info("Finished importing");
print "Finished with $buffer records\n";
