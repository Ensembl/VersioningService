use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::EnsEMBL::Versioning::DB;
use Bio::EnsEMBL::Test::MultiTestDB;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $versioning_dba = $multi->get_DBAdaptor('versioning');
Bio::EnsEMBL::Versioning::DB->register_DBAdaptor($versioning_dba);

require Bio::EnsEMBL::Versioning::Manager::Version;
require Bio::EnsEMBL::Versioning::Manager::Process;
require Bio::EnsEMBL::Versioning::Manager::Source;
require Bio::EnsEMBL::Versioning::Manager::SourceGroup;
require Bio::EnsEMBL::Versioning::Manager::SourceDownload;
require Bio::EnsEMBL::Versioning::Manager::Resources;
require Bio::EnsEMBL::Versioning::Manager::Run;


my $source_group = Bio::EnsEMBL::Versioning::Object::SourceGroup->new(name => 'UniprotGroup');
$source_group->save();
print $source_group->source_group_id . " id when created with " . $source_group->created_date . " created date\n";
my $source = Bio::EnsEMBL::Versioning::Object::Source->new(name => 'Uniprot', source_group_id => $source_group->source_group_id);
print $source->source_group->name . " source group name for source\n";
print $source->source_group_id . " and corresponding internal id\n";
$source->save();
my $second_source = Bio::EnsEMBL::Versioning::Object::Source->new(name => 'UniprotTrEMBL', source_group_id => $source_group->source_group_id);
$second_source->save();
print $source->active() . " source is active\n";
my $version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '12', source_id => $source->source_id, record_count => 350, is_current => 1);
print $version->version() . " new version version\n";
print $version->source->name() . " new version source name\n";
$version->save();

my $second_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '11', source_id => $source->source_id, record_count => 450);
$second_version->save();
my $third_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '11', source_id => $second_source->source_id, record_count => 250);
$third_version->save();

my $versions = Bio::EnsEMBL::Versioning::Manager::Version->get_versions();
my $sources = Bio::EnsEMBL::Versioning::Manager::Source->get_objects();
my $processes = Bio::EnsEMBL::Versioning::Manager::Process->get_objects();
my $source_groups = Bio::EnsEMBL::Versioning::Manager::SourceGroup->get_objects();
my $source_downloads = Bio::EnsEMBL::Versioning::Manager::SourceDownload->get_objects();
my $resources = Bio::EnsEMBL::Versioning::Manager::Resources->get_objects();
my $runs = Bio::EnsEMBL::Versioning::Manager::Run->get_objects();

my $all_versions = Bio::EnsEMBL::Versioning::Manager::Version->get_all_versions('Uniprot');
my $many_versions = Bio::EnsEMBL::Versioning::Manager::Version->get_objects();
print scalar(@$all_versions) . " all versions compared to " . scalar(@$many_versions) . " many versions\n";
my $current = Bio::EnsEMBL::Versioning::Manager::Version->get_current('Uniprot');
print $current->version . " current uniprot version\n";

my $test_source = Bio::EnsEMBL::Versioning::Manager::Source->get_objects(
        with_objects => ['version'],
        query =>
        [
          name => 'Uniprot',
          'version.version' => '12',
         ]);
my $second_versions = Bio::EnsEMBL::Versioning::Manager::Version->get_objects(
        with_objects => ['source'],
        query =>
        [
          'source.name' => { like => 'Kite%' },
          version_id   => { gt => 15 },
        ],
        sort_by => 'source.name');

