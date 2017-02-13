use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Differences;

use FindBin qw/$Bin/;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UCSC';
my $ucsc = Bio::EnsEMBL::Versioning::Pipeline::Downloader::UCSC->new();
isa_ok($ucsc, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UCSC');

my $version = $ucsc->get_version;
note("Downloading UCSC version (timestamp): " . $version);

my $result = $ucsc->download_to($Bin);
my $expected = [ "$Bin/hg38.txt.gz", "$Bin/mm10.txt.gz"];
cmp_deeply($result, $expected, 'Download of matching UCSC files successful');

unlink @{$expected};

done_testing;
