use strict;
use warnings;

use Test::More;
use Test::Differences;
use Cwd;

use FindBin qw/$Bin/;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RGD';
my $rgd = Bio::EnsEMBL::Versioning::Pipeline::Downloader::RGD->new();
isa_ok($rgd, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RGD');

my $version = $rgd->get_version;
note("Downloading RGD version (timestamp): " . $version);

my $result = $rgd->download_to($Bin);
is($result->[0], "$Bin/GENES_RAT.txt", 'Download of matching RGD file successful');

unlink "$Bin/GENES_RAT.txt";

done_testing;
