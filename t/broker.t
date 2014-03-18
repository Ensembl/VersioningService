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

use Bio::EnsEMBL::Versioning::Broker;
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $versioning_dba = $multi->get_DBAdaptor('versioning');
Bio::EnsEMBL::Versioning::DB->register_DBAdaptor($versioning_dba);

my $uniprot_source = Bio::EnsEMBL::Versioning::Object::Source->new(name => 'UniProtSwissprot', parser => 'UniProtParser');
$uniprot_source->source_group(name => 'UniProtGroup');
$uniprot_source->save();
my $uniprot_version = Bio::EnsEMBL::Versioning::Object::Version->new(revision => '2013_12', record_count => 49243530, uri => '/lustre/scratch110/ensembl/mr6/Uniprot/203_12/uniprot.txt');
$uniprot_version->source($uniprot_source);
$uniprot_version->save();

my $refseq_source = Bio::EnsEMBL::Versioning::Object::Source->new(name => 'RefSeq', parser => 'RefSeqParser');
$refseq_source->source_group(name => 'RefSeqGroup');

my $refseq_version = Bio::EnsEMBL::Versioning::Object::Version->new(revision => '61', record_count => 49243530, uri => '/lustre/scratch110/ensembl/mr6/RefSeq/61/refseq.txt');
$refseq_version->source($refseq_source);
$refseq_version->save();

my $second_version = Bio::EnsEMBL::Versioning::Object::Version->new(revision => '60', record_count => 40000, uri => '/lustre/scratch110/ensembl/mr6/RefSeq/61/refseq.txt');
$second_version->source($refseq_source);
$second_version->save();
$refseq_source->current_version($second_version->version_id);
$refseq_source->save;



my $broker = Bio::EnsEMBL::Versioning::Broker->new;

my $list = $broker->list_versions_by_source('RefSeq');
is_deeply($list,[60,61],'Both versions of test data returned');
my $source = $broker->get_current_source_by_name('RefSeq');
cmp_ok($source->version->[0]->revision,'==',60,'Check release revision is correct');

$source = $broker->get_source_by_name_and_version('RefSeq',61);
cmp_ok($source->version->[0]->revision,'==',61,'Source fetching by specific version');

done_testing;