use strict;
use warnings;

use Test::More;
use Test::Differences;

use FindBin qw/$Bin/;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::Xenbase';
my $xenbase = Bio::EnsEMBL::Versioning::Pipeline::Downloader::Xenbase->new();
isa_ok($xenbase, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::Xenbase');

my $version = $xenbase->get_version;
note("Downloading Xenbase version (timestamp): " . $version);

my $result = $xenbase->download_to($Bin);
is($result->[0], "$Bin/GenePageEnsemblModelMapping.txt", 'Download of matching Xenbase file successful');

unlink "$Bin/GenePageEnsemblModelMapping.txt";

done_testing;
