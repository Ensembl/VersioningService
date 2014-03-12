use Test::More;
use Test::Differences;
use Cwd;
use Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq;
use FindBin qw/$Bin/;

use Log::Log4perl;
Log::Log4perl::init("$Bin/../conf/logger.conf");

my $refseq = Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq->new();
$refseq->file_pattern('vertebrate_mammalian\.55\.protein.*');

my $version = $refseq->get_version;
cmp_ok($version,'==',63,'Current RefSeq version is as expected');

my $result = $refseq->download_to(cwd());
is($result->[0],cwd().'/vertebrate_mammalian.55.protein.gpff.gz','Download of single Refseq file successful');
is($result->[1],cwd().'/vertebrate_mammalian.55.protein.faa.gz','Download of second Refseq file successful');

done_testing;