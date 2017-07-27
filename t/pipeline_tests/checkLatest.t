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
my $version = $broker->schema->resultset('Version')->create(
  {
    revision => 100,
    uri => '/path/to/download',
    sources => $source,
    count_seen => 1
  }
);

note "Test an invalid source";
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


note "Check a real source against a remote with higher version";
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

note "Test the presentation of a version without an index.";
$mock_downloader = Test::MockObject->new();
$mock_downloader->fake_module('Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS', get_version => sub { return 100 });

standaloneJob(
  'Bio::EnsEMBL::Versioning::Pipeline::CheckLatest',
  $config,
  [
    ['WARNING', 'Flowing BadTLA with 100 to downloading for updater pipeline',],
    ['DATAFLOW', { source_name => 'BadTLA', version => 100}, 2]
  ]
);


note "create a version with an index URI already in place. CheckLatest should not do anything at all.";

my $new_version = $broker->schema->resultset('Version')->create(
  {
    revision => 100,
    uri => '/path/to/download',
    index_uri => '/path/to/index',
    sources => $source,
    count_seen => 1
  }
);

$source->current_version($new_version);
$source->update;

standaloneJob(
  'Bio::EnsEMBL::Versioning::Pipeline::CheckLatest',
  $config,
  [
    ['WARNING', 'Source BadTLA left at version 100',]
  ]
);


done_testing;