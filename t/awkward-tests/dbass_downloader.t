use strict;
use warnings;

use Test::More;
use Test::Differences;
use Cwd;

use FindBin qw/$Bin/;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS';
my $dbass = Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS->new();
isa_ok($dbass, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS');

my $version = $dbass->get_version;
note("Downloading DBASS version (timestamp): " . $version);

my $result = $dbass->download_to($Bin);
is($result->[0], "$Bin/dbass.csv", 'Download of matching DBASS file successful');

unlink "$Bin/dbass.csv";

done_testing;
