use strict;
use warnings;

use Test::More;
use Test::Differences;
use Cwd;

use FindBin qw/$Bin/;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MiRBase';
my $mirbase = Bio::EnsEMBL::Versioning::Pipeline::Downloader::MiRBase->new();
isa_ok($mirbase, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MiRBase');

my $version = $mirbase->get_version;
note("Downloading MiRBase version (timestamp): " . $version);

my $result = $mirbase->download_to($Bin);
is($result->[0], "$Bin/miRNA.dat.gz", 'Download of matching MiRBase file successful');

unlink "$Bin/miRNA.dat.gz";

done_testing;
