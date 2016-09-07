# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Env;
use Bio::EnsEMBL::Versioning::Broker;
use Bio::EnsEMBL::Versioning::TestDB qw/broker/;
use File::Temp qw/tempfile tempdir/;
use Test::MockObject::Extends;
use Test::MockObject;

my $broker = broker();
# throw in some test data
# consider changing to "fixtures", for neat and tidy test data.
my $uniprot_version = $broker->schema->resultset('Version')->create({revision => '2013_12', record_count => 49243530, uri => '/lustre/scratch110/ensembl/Uniprot/203_12/uniprot.txt', count_seen => 1});

my $uniprot_group = $broker->schema->resultset('SourceGroup')->create({ name => 'UniProtGroup' });
my $uniprot_source = $uniprot_group->create_related('sources', {name=> 'UniProt/SWISSPROT', parser => 'UniProtParser', current_version => $uniprot_version, active => 1, downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtSwissProt'});

# Connect version to source now that it exists
$uniprot_version->sources($uniprot_source);
$uniprot_version->update;

ok($uniprot_source->in_storage(),"Source created in DB");
ok($uniprot_version->in_storage(),"Version created in DB");
ok($uniprot_group->in_storage(),"Group created in DB");

my $refseq_group = $broker->schema->resultset('SourceGroup')->create({ name => 'RefSeqGroup' });
my $refseq_source = $refseq_group->create_related('sources', {name => 'RefSeq', parser => 'RefSeqParser', active=> 1});

my $first_version = $refseq_source->create_related('versions', {revision => '61', record_count => 49243530, uri => '/lustre/scratch110/ensembl/RefSeq/61/refseq.txt', count_seen => 1});
my $second_version = $refseq_source->create_related('versions', {revision => '60', record_count => 40000, uri => '/lustre/scratch110/ensembl/RefSeq/61/refseq.txt',count_seen => 1});

$refseq_source->update( {current_version => $second_version});

my $list = $broker->list_versions_by_source('RefSeq');
is_deeply($list,[61,60],'Both versions of test data returned');
dies_ok( sub { $broker->list_versions_by_source('Bingly-bongly') },'No versions for strange source, system complains');

my $version = $broker->get_current_version_of_source('RefSeq');
cmp_ok($version->revision,'==',60,'Check release revision is correct');

$version = $broker->get_version_of_source('RefSeq',61);
cmp_ok($version->revision,'==',61,'Source fetching by specific version');

$broker->already_seen($version);
$version = $broker->get_version_of_source('RefSeq',61);
cmp_ok( $version->count_seen, '==', 2, 'Times this revision has been seen can be incremented if a source is not receiving an update' );
$broker->already_seen($version);
$version = $broker->get_version_of_source('RefSeq',61);
cmp_ok( $version->count_seen, '==', 3, 'More times this revision has been seen can be incremented if a source is not receiving an update' );
# Test finalise methods

my $dir = tempdir();
my ($fh,$temp_source) = tempfile('sourceXXXX',DIR => $dir);
my $dh = IO::File->new($dir.'/index','w');
$dh->close;
$version->uri($dir);
$version->index_uri($dir.'/index');

my $file_list = $broker->get_file_list_for_version($version);
is_deeply($file_list, [$temp_source],'File list does not contain index, even if an index already exists');
unlink $dir.'/index';
note @$file_list;
my $moved_file_list = $broker->shunt_to_fast_disk($file_list);
note @$moved_file_list;


ok(scalar @$moved_file_list > 0, 'Files were moved');
cmp_ok(scalar @$moved_file_list, '==', scalar @$file_list, 'Equal number of files before and after copy');

my @temp_paths = ($broker->temp_location,$broker->temp_location,$broker->temp_location);
note "Threaded paths:".join ',',@temp_paths;
foreach my $path (@temp_paths) {
  print "Yay $path\n" if -w $path
}


$broker = Test::MockObject::Extends->new($broker);
$broker->mock( 'location', sub { return tempdir() });

my $new_path = $broker->finalise_download($uniprot_source,'2015_06',$dir);
ok($new_path,'Broker able to move new files into versioning');
is_deeply( $broker->list_versions_by_source('UniProt/SWISSPROT'), ['2013_12','2015_06'],'Versioning DB updated' );

# Create a fake document store to bypass onerous configuration
my $docstore = Test::MockObject->new();
$docstore->mock( 'index', sub { return tempdir() });

$broker->finalise_index($uniprot_source, '2015_06', $docstore, 666);
is($broker->get_current_version_of_source('UniProt/SWISSPROT')->revision, '2015_06', 'finalise_index() sets new current version');

# Fetch the location of the index we've just 'created'

my $index_uri = $broker->get_index_by_name_and_version('UniProt/SWISSPROT','2015_06');
my $other_index_uri = $broker->get_index_by_name_and_version('UniProt/SWISSPROT');
ok($index_uri,'Index URI returned');
ok($other_index_uri,'Index returned via current');
is($index_uri,$other_index_uri,'Same URI retrieved by different routes');

my @sources = @{ $broker->get_active_sources };
ok(scalar @sources == 2, 'Found two active sources');

ok($broker->add_new_source('UniParc','UniProtGroup',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtUniParc','Bio::EnsEMBL::Mongoose::Parser::Uniparc'),'Try to create a new source');
throws_ok( sub { $broker->add_new_source('UniPurple','UniProtGroup',1,'Bio::Pish::Purple','Bilge::Pish::Purple') }, qr/is not of type PackageName/,'Source add fails on untestable downloader/parser code');

my $downloader;
ok( $downloader = $broker->get_downloader('UniProt/SWISSPROT'), "Loading downloader module proceeds successfully" );
is($downloader,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtSwissProt','Test correct download module name returned');
my $module = $broker->get_module($downloader);
ok($module->isa('Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtSwissProt'),'Check module can be loaded successfully');

# Bug test for multiple versions of any source with the same release causing new indexes to be stored incorrectly

my $hgnc_group = $broker->schema->resultset('SourceGroup')->create({ name => 'HGNCGroup' });
my $hgnc_source = $hgnc_group->create_related('sources', {name => 'HGNC', parser => 'HGNCParser', active=> 1});

my $mim_group = $broker->schema->resultset('SourceGroup')->create({ name => 'MIMGroup' });
my $mim_source = $mim_group->create_related('sources', {name => 'MIM', parser => 'MIMParser', active=> 1});

my $third_version = $hgnc_source->create_related('versions', {revision => '07092016', uri => '/HGNC/hgnc.json', count_seen => 1, record_count => 1});
my $fourth_version = $mim_source->create_related('versions', {revision => '07092016', uri => '/MIM/MIM.txt',count_seen => 1});

$hgnc_source->update( {current_version => $third_version});
$mim_source->update( {current_version => $fourth_version});

$broker->finalise_index($mim_source, '07092016', $docstore, 100); # if bug present, this should modify the HGNC version instead of the MIM version
is($broker->get_current_version_of_source('MIM')->record_count, '100', 'Correct source gets updated with ambiguous revision number');
is($broker->get_current_version_of_source('HGNC')->record_count, '1', 'Other source does not get updated');

done_testing;