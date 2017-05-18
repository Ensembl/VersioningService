# zfin_download.t

use Test::More;
use Test::Differences;
use Cwd;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::ZFIN';

my $hgnc = Bio::EnsEMBL::Versioning::Pipeline::Downloader::ZFIN->new();
my $version = $hgnc->get_version;

my $result = $hgnc->download_to(cwd());
ok ($result,'Got ZFIN data');

my $expected_files = [cwd().'/uniprot.txt',cwd().'/refseq.txt',cwd().'/aliases.txt'];

is_deeply($result, $expected_files, 'Files acquired');

foreach my $file (@$expected_files) {
  unlink $file;
}

done_testing;
