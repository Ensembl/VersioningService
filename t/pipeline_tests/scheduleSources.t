use Modern::Perl;
use Bio::EnsEMBL::Hive::Utils::Test qw/standaloneJob/;
use Bio::EnsEMBL::Versioning::Pipeline::ScheduleSources;
use Test::More;
use lib "$ENV{MONGOOSE}/t/";
# use TestDefaults;
use Bio::EnsEMBL::Versioning::TestDB qw/broker/;

# Mock up a test SQlite DB and send the DSN into the hive test

my $broker = broker();
$broker->add_new_source('BadTLA','BuzzInformatics',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS','Bio::EnsEMBL::Mongoose::Parser::DBASS');
$broker->add_new_source('FlatFilesRUs','RebelAlliance',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS','Bio::EnsEMBL::Mongoose::Parser::DBASS');
my $config = $broker->config; # Connection details for the TestDB

standaloneJob(
  'Bio::EnsEMBL::Versioning::Pipeline::ScheduleSources',
  $config,
  [
    ['WARNING', 'Found 2 active source(s) to process',],
    ['DATAFLOW', {source_name => 'BadTLA'}, 2],
    ['DATAFLOW', {source_name => 'FlatFilesRUs'}, 2]
  ]
);



done_testing;