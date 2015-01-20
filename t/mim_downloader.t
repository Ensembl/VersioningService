use Test::More;
use Test::Differences;
use Cwd;
use Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $mim = Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM->new();
# $mim->file_pattern('complete\.55\.bna.*');

my $version = $mim->get_version;
# cmp_ok($version,'==',69,'Current mim version is as expected'); # Not version independent obviously
note("Downloading mim version: ".$version);

my $result = $mim->download_to(cwd());
# is($result->[0],cwd().'/complete.55.1.genomic.fna.gz','Download of single Refseq file successful');
is($result->[0],cwd().'/omim.txt.Z','Download of matching OMIM file successful');
# is($result->[0],cwd().'/complete.55.genomic.gbff.gz','Download of third Refseq file successful');

done_testing;