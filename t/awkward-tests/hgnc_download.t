# hgnc_download.t

use Test::More;
use Test::Differences;
use Cwd;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HGNC';

my $hgnc = Bio::EnsEMBL::Versioning::Pipeline::Downloader::HGNC->new();
my $version = $hgnc->get_version;

my $result = $hgnc->download_to(cwd());
ok ($result,'Got HGNC data');
is ($result->[0],cwd().'/hgnc.json', 'File named correctly');
ok (-e cwd().'/hgnc.json', 'File also in filesystem');
unlink cwd().'/hgnc.json';

done_testing;
