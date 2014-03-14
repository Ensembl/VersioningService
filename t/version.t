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
require Bio::EnsEMBL::Versioning::Manager::Resources;
require Bio::EnsEMBL::Versioning::Manager::Run;


my $source_group = Bio::EnsEMBL::Versioning::Object::SourceGroup->new(name => 'UniprotGroup');
$source_group->save();

my $source = Bio::EnsEMBL::Versioning::Object::Source->new(name => 'RefSeq', module => 'RefSeqParser');
$source->source_group(name => 'RefSeqGroup');
$source->save();
cmp_ok($source->source_group_id,'==', 2, "Source group was saved along with source");

my $version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '12', record_count => 350);
$version->source(name => 'Uniprot');
$version->source->source_group(name => 'UniprotGroup');
$version->save();
cmp_ok($version->source->source_id,'==', 2, "Uniprot was correctly saved");

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
cmp_ok($run_process->[0]->run->run_id,'==', $run->run_id(), "Retrieving process from run object and run object from process");

my $second_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '11', record_count => 999);
$second_version->source(name => 'Uniprot');
$second_version->save();

my $third_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '12', record_count => 238);
$third_version->source(name => 'UniprotTrEMBL');
$third_version->source->source_group(name => 'UniprotGroup');
$third_version->save();

my $group_sources = $source_group->source();
cmp_ok(scalar(@$group_sources),'==', 2, "Two sources for UniprotGroup");


my $versions = Bio::EnsEMBL::Versioning::Manager::Version->get_versions();
cmp_ok(scalar(@$versions), '==', 3, "Fetched all version");
my $uniprot_versions = Bio::EnsEMBL::Versioning::Manager::Version->get_all_versions('Uniprot');
cmp_ok(scalar(@$uniprot_versions),'==', 2, "Found all Uniprot versions");

my $current = Bio::EnsEMBL::Versioning::Manager::Version->get_current('Uniprot');
cmp_ok($current->version(),'==', 12, "Matching current version for Uniprot");

my $all_versions = $source->version();
cmp_ok(scalar(@$all_versions),'==', 0, "Refseq source has no versions");

my $current_release_resource = Bio::EnsEMBL::Versioning::Manager::Resources->get_release_resource('RefSeq');
is($release_resource->name, 'refseq_release', 'Found refseq release resource'); 


done_testing();
