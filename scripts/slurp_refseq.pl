use strict;
use warnings;

use FindBin qw/$Bin/;
use Log::Log4perl;
use Data::Dump::Color qw/dump/;
use Devel::Size qw/total_size/;

use Config::General;

my $conf = Config::General->new("$Bin/../conf/refseq.conf");
my %opts = $conf->getall();

Log::Log4perl::init("$Bin/../conf/logger.conf");

use Bio::EnsEMBL::IO::GenbankParser->open($opts->{refseq_file});
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;

my $buffer = 0;
my $logger = Log::Log4perl->get_logger();

$logger->info("Beginning to parse ".$opts{data_location});

while($parser->next) {
    
}

print "Wayhay!\n";