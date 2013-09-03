use strict;
use warnings;

use FindBin qw/$Bin/;
use Log::Log4perl;
use Data::Dump::Color qw/dump/;

use Config::General;

my $conf = Config::General->new("$Bin/../conf/swissprot.conf");
my %opts = $conf->getall();

Log::Log4perl::init("$Bin/../conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Parser::Swissprot;
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;

my $parser = Bio::EnsEMBL::Mongoose::Parser::Swissprot->new( source_file => $opts{data_location} );
my $doc_store = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new( index => $opts{index_location});

my $buffer = 0;
my $logger = Log::Log4perl->get_logger();

$logger->info("Beginning to parse ".$opts{data_location});

while ($parser->read_record) {
    my $record = $parser->record;
    printf "Main accession: %s, Gene name: %s, Taxon: %s\n",
    $record->primary_accession,$record->gene_name ? $record->gene_name : '', $record->taxon_id;
    $doc_store->store_record($record);
    $buffer++;
    if ($buffer % 100000 == 0) {
        $logger->info("Committing 100000 records");
        $doc_store->commit;
    }
};

$doc_store->commit;
$logger->info("Finished importing");