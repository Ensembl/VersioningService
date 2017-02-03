use Test::More;
use Test::Differences;
use Cwd;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM';
use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM2GeneMedGen';

my $mim = Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM->new();
my $version = $mim->get_version;
note("Downloading mim version (timestamp): ".$version);

my $result = $mim->download_to(cwd());
is($result->[0],cwd().'/omim.txt.gz','Download of matching OMIM file successful');

$mim = Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM2GeneMedGen->new();
$version = $mim->get_version();
note("Downloading mim2gene version (timestamp): ".$version);

$result = $mim->download_to(cwd());
is($result->[0],cwd().'/mim2gene_medgen','Download of matching MIM2Gene file successful');

done_testing;