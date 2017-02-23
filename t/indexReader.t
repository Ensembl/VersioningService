use strict;
use Test::More;
use Test::Differences;
use Test::Exception;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
use FindBin qw/$Bin/;
use Bio::EnsEMBL::Mongoose::IndexReader;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;

my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    ids => ['Q13878'],
    id_type => 'accessions',
    evidence_level => 1,
    taxons => [9606],
);

my $reader = Bio::EnsEMBL::Mongoose::IndexReader->new(
    storage_engine_conf_file => "$Bin/../conf/test.conf",
    query_params => $params,
);

my $count = $reader->how_many_hits;
cmp_ok($count, '==', 1,"Query returns a single result");
my $record = $reader->next_record;

is($record->primary_accession,'P15056','Found the intended record as per primary accession');

$params->ids([]);
$params->taxons([]);
$params->species_name('Pulchrana picturata');

$reader->convert_name_to_taxon;
is($params->taxons->[0],395594,'Test name conversion');
$params->clear_species_name;
$params->taxons([8397]);
# test blacklist
my $blacklist_file = 'data/blacklist.txt';
$reader->blacklist_source($blacklist_file); # Does not really test very much at the moment
$reader->next_record;

# Test what happens when bad user data is supplied

$reader = Bio::EnsEMBL::Mongoose::IndexReader->new(
    storage_engine_conf_file => "$Bin/../conf/test.conf",
    
);
$params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    species_name => 'Morlock'
);
throws_ok( sub { $reader->query($params) }, 'Bio::EnsEMBL::Mongoose::SearchEngineException', 'Bad species name causes an exception explaining why');

# Test for checksums via accessors

done_testing;