use Modern::Perl;
use Test::More;
use Test::Differences;
use FindBin qw/$Bin/;
use Bio::EnsEMBL::Versioning::Pipeline::Downloader::RNAcentral;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RNAcentral';

my $rna = Bio::EnsEMBL::Versioning::Pipeline::Downloader::RNAcentral->new();
my $version = $rna->get_version;
note("Downloading rna version : ".$version);

my $result = $rna->download_to($Bin);
is($result->[0],$Bin.'/rna.txt.gz','Download of matching file successful');

# unlink "$Bin/rna.txt.gz";

done_testing;