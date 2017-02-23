use strict;
use warnings;

use Test::More;
use Test::Differences;
use Cwd;

use FindBin qw/$Bin/;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::VGNC';
my $vgnc = Bio::EnsEMBL::Versioning::Pipeline::Downloader::VGNC->new();
isa_ok($vgnc, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::VGNC');

my $version = $vgnc->get_version;
note("Downloading VGNC version (timestamp): " . $version);

my $result = $vgnc->download_to($Bin);
is($result->[0], "$Bin/chimpanzee_vgnc_gene_set_All.txt", 'Download of matching VGNC file successful');

unlink "$Bin/chimpanzee_vgnc_gene_set_All.txt";

done_testing;
