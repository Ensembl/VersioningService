use strict;
use warnings;

use Test::More;
use Test::Differences;
use Cwd;

use FindBin qw/$Bin/;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HPA';
my $hpa = Bio::EnsEMBL::Versioning::Pipeline::Downloader::HPA->new();
isa_ok($hpa, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HPA');

my $version = $hpa->get_version;
note("Downloading HPA version (timestamp): " . $version);

my $result = $hpa->download_to($Bin);
is($result->[0], "$Bin/hpa.csv", 'Download of matching HPA file successful');

unlink "$Bin/hpa.csv";

done_testing;
