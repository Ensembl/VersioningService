use Test::More;
use Test::Differences;
use Cwd;
use Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $refseq = Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq->new();
$refseq->file_pattern('complete\.55\.bna.*');

my $version = $refseq->get_version;
# cmp_ok($version,'==',69,'Current RefSeq version is as expected'); # Not version independent obviously
note("Downloading Refseq version: ".$version);

my $result = $refseq->download_to(cwd());
# is($result->[0],cwd().'/complete.55.1.genomic.fna.gz','Download of single Refseq file successful');
is($result->[0],cwd().'/complete.55.bna.gz','Download of only matching Refseq file successful');
# is($result->[0],cwd().'/complete.55.genomic.gbff.gz','Download of third Refseq file successful');

done_testing;