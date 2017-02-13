use Test::More;
use Test::Differences;
use Cwd;
use Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq;

my $refseq = Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq->new();
$refseq->file_pattern('complete\.55\.bna.*');

my $version = $refseq->get_version;
# cmp_ok($version,'==',69,'Current RefSeq version is as expected'); # Not version independent obviously
note("Downloading Refseq version: ".$version." to ".cwd());

my $result = $refseq->download_to(cwd());
# is($result->[0],cwd().'/complete.55.1.genomic.fna.gz','Download of single Refseq file successful');
is($result->[0],cwd().'/complete.55.bna.gz','Download of only matching Refseq file successful');
# is($result->[0],cwd().'/complete.55.genomic.gbff.gz','Download of third Refseq file successful');
ok(-e cwd().'/complete.55.bna.gz','File was actually written to disk');

unlink(cwd().'/complete.55.bna.gz');
done_testing;