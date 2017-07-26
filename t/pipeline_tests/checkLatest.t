use Modern::Perl;
use Bio::EnsEMBL::Hive::Utils::Test qw/standaloneJob/;
use Bio::EnsEMBL::Versioning::Pipeline::CheckLatest;
use Test::More;
use Test::MockObject;
use lib "$ENV{MONGOOSE}/t/";
use Bio::EnsEMBL::Versioning::TestDB qw/broker/;

# Mock up a test SQlite DB and send the DSN into the hive test

# Spoof a source and version to compare with a remote version

my $broker = broker();
my $source = $broker->add_new_source('BadTLA','BuzzInformatics',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS','Bio::EnsEMBL::Mongoose::Parser::DBASS');
# can't use finalise_index() without messing with file systems
# Create the local version directly
$broker->schema->resultset('Version')->create(
  {
    revision => 100,
    uri => '/path/to/index',
    sources => $source,
    count_seen => 1
  }
);

my $config = $broker->config; # Connection details for the TestDB
$config->{source_name} = 'Bogus source'; # Set input ID for Runnable

standaloneJob(
  'Bio::EnsEMBL::Versioning::Pipeline::CheckLatest',
  $config,
  [
    ['WARNING', qr/Cannot find source Bogus source to supply downloader module/,1],
  ],
  {expect_failure => 1}
);


# Now check the spoofed source against a remote
$config->{source_name} = 'BadTLA';

my $mock_downloader = Test::MockObject->new();
$mock_downloader->fake_module('Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS', get_version => sub { return 110 });

standaloneJob(
  'Bio::EnsEMBL::Versioning::Pipeline::CheckLatest',
  $config,
  [
    ['WARNING', 'Flowing BadTLA with 110 to downloading for updater pipeline',],
    ['DATAFLOW', { source_name => 'BadTLA', version => 110},2],
  ]
);

done_testing;