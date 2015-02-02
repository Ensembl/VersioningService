# hgnc_download.t

use Test::More;
use Test::Differences;
use Cwd;
use Bio::EnsEMBL::Versioning::Pipeline::Downloader::HGNC;
use Data::Dumper;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $hgnc = Bio::EnsEMBL::Versioning::Pipeline::Downloader::HGNC->new();
my $version = $hgnc->get_version;

my $result = $hgnc->download_to(cwd());
ok ($result,'Got HGNC data');
is ($result->[0],cwd().'/hgnc.json', 'File named correctly');
ok (-e cwd().'/hgnc.json', 'File also in filesystem');
unlink cwd().'/hgnc.json';