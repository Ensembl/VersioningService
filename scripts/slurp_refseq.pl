use strict;
use warnings;

use FindBin qw/$Bin/;
use Log::Log4perl;
use Data::Dump::Color qw/dump/;
use Devel::Size qw/total_size/;

use Config::General;

my $conf = Config::General->new("$ENV{MONGOOSE}/conf/refseq.conf");
my %opts = $conf->getall();

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Parser::Refseq;
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;
my $parser = Bio::EnsEMBL::Mongoose::Parser::Refseq->new(source_file => $opts{data_location});
my $doc_store = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new( index => $opts{index_location});

my $buffer = 0;
my $logger = Log::Log4perl->get_logger();

$logger->info("Beginning to parse ".$opts{data_location});

while($parser->read_record) {
    my $record = $parser->record;
    printf "Main accession: Gene name: %s, Taxon: %s\n", $record->id, $record->taxon_id;
    $doc_store->store_record($record);
    $buffer++;
    if ($buffer % 100000 == 0) {
        $logger->info("Committing 100000 records");
#        $logger->info("Parser:".total_size $parser);
        $logger->info("MEM: ".`ps --no-headers -p $$ -o rss=`);
        $doc_store->commit;
        $doc_store = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new( index => $opts{index_location});
#        $logger->info("MEM2: ".`ps -p $$ -h -o rss=`);
    }
}
$doc_store->commit;
print "Wayhay!\n";