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

my $source = Bio::EnsEMBL::Versioning::Object::Source->new(name => 'RefSeq');
$source->source_group(name => 'RefSeqGroup');
$source->save();
is($source->source_group_id, 2, "Source group was saved along with source");

my $resource = Bio::EnsEMBL::Versioning::Object::Resources->new(name => 'refseq_file', type => 'file', value => 'refseq.txt');
$resource->source_download(module => 'RefSeqParser');
$resource->source_download->source(name => 'RefSeq');
$resource->save();
is($resource->source_download_id(), 1, "Source download was saved along with resource");

my $source_download = @{ Bio::EnsEMBL::Versioning::Manager::SourceDownload->get_source_download(module => 'RefSeqParser') }->[0];
my $download_resources = $source_download->resources();
is($download_resources->[0]->source_download->module(), $source_download->module(), "Can retrieve resources from source_download and source_download from resources");

my $version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '12', record_count => 350, is_current => 1);
$version->source(name => 'Uniprot');
$version->source->source_group(name => 'UniprotGroup');
$version->save();
is($version->source->source_id, 2, "Uniprot was correctly saved");

my $run = Bio::EnsEMBL::Versioning::Object::Run->new(start => 'now()');
$run->version($version);
$run->save();
my $process = Bio::EnsEMBL::Versioning::Object::Process->new(name => 'update');
$process->run($run);
$process->save();
is($process->run->start(), 'now()', "Updated start date for run");
my $runs = $version->run();
is($runs->[0]->version->[0]->version(), $version->version(), "Successfully retrieved run from version object");
my $run_process = $run->process();
is($run_process->[0]->run->run_id, $run->run_id(), "Retrieving process from run object and run object from process");

my $second_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '11', record_count => 999);
$second_version->source(name => 'Uniprot');
$second_version->save();

my $third_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '12', record_count => 238, is_current => 1);
$third_version->source(name => 'UniprotTrEMBL');
$third_version->source->source_group(name => 'UniprotGroup');
$third_version->save();

my $group_sources = $source_group->source();
is(scalar(@$group_sources), 2, "Two sources for UniprotGroup");


my $versions = Bio::EnsEMBL::Versioning::Manager::Version->get_versions();
is(scalar(@$versions), 3, "Fetched all version");
my $uniprot_versions = Bio::EnsEMBL::Versioning::Manager::Version->get_all_versions('Uniprot');
is(scalar(@$uniprot_versions), 2, "Found all Uniprot versions");

my $current = Bio::EnsEMBL::Versioning::Manager::Version->get_current('Uniprot');
is($current->version(), 12, "Matching current version for Uniprot");

my $second_current = Bio::EnsEMBL::Versioning::Manager::Source->get_current('Uniprot');
is($current->version(), $second_current->version(), "Returned same current version via source and via version");

my $all_versions = $source->version();
is(scalar(@$all_versions), 0, "Refseq source has no versions");

done_testing();
