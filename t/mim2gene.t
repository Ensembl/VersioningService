use Test::More;
use Test::Differences;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Parser::MIM2Gene;

my $reader = new Bio::EnsEMBL::Mongoose::Parser::MIM2Gene(
    source_file => "data/mim2gene.txt",
);

$reader->read_record; #first one is empty...
my $record = $reader->record;

is($record->id,'100050','ID extraction from column 1');
$reader->read_record;
$record = $reader->record;
is($record->id,'100070','ID of second record');

done_testing;