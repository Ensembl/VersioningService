use Test::More;
use Test::Differences;

use FindBin qw/$Bin/;
use Log::Log4perl;
Log::Log4perl::init("$Bin/../conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Mfetcher;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use IO::String;
my $out;
my $fh = IO::String->new($out);

my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    ids => ['P15056'],
    id_type => 'accessions',
    evidence_level => 1,
    taxons => [395594],
);

my $mfetcher = Bio::EnsEMBL::Mongoose::Mfetcher->new(
    storage_engine_conf => "$Bin/../conf/swissprot.conf",
    query_params => $params,
    handle => $fh,
);

$mfetcher->get_sequence;

my $desired = "> P0C8T7 395594 1 
GFLDSFKNAMIGVAKSVGKTALSTLACKIDKSC
";
is($out,$desired, 'Check FASTA output');

$params->ids([]);
$params->taxons([]);
$params->species_name('Hylarana picturata');

$mfetcher->convert_name_to_taxon;
is($params->taxons->[0],395594,'Test name conversion');

done_testing;