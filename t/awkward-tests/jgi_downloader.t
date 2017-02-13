use strict;
use warnings;

use Test::More;
use Test::Differences;
use Cwd;

use FindBin qw/$Bin/;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::JGI';
my $jgi = Bio::EnsEMBL::Versioning::Pipeline::Downloader::JGI->new();
isa_ok($jgi, 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::JGI');

my $version = $jgi->get_version;
note("Downloading JGI version (timestamp): " . $version);

my $result = $jgi->download_to($Bin);
is($result->[0], "$Bin/ciona.prot.fasta.gz", 'Download of matching JGI file successful');

unlink "$Bin/ciona.prot.fasta.gz";

done_testing;
