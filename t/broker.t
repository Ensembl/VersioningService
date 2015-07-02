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


my $broker = broker();
# throw in some test data
# consider changing to "fixtures", for neat and tidy test data.
# $broker->schema->result();
my $uniprot_version = $broker->schema->resultset('Version')->create({revision => '2013_12', record_count => 49243530, uri => '/lustre/scratch110/ensembl/Uniprot/203_12/uniprot.txt', count_seen => 1});

my $uniprot_group = $broker->schema->resultset('SourceGroup')->create({ name => 'UniProtGroup' });
my $uniprot_source = $uniprot_group->create_related('sources', {name=> 'UniProtSwissprot', parser => 'UniProtParser', current_version => $uniprot_version});

ok($uniprot_source->in_storage(),"Source created in DB");

my $refseq_group = $broker->schema->resultset('SourceGroup')->create({ name => 'RefSeqGroup' });
my $refseq_source = $refseq_group->create_related('sources', {name => 'RefSeq', parser => 'RefSeqParser'});

my $first_version = $refseq_source->create_related('versions', {revision => '61', record_count => 49243530, uri => '/lustre/scratch110/ensembl/RefSeq/61/refseq.txt', count_seen => 1});
my $second_version = $refseq_source->create_related('versions', {revision => '60', record_count => 40000, uri => '/lustre/scratch110/ensembl/RefSeq/61/refseq.txt',count_seen => 1});

$refseq_source->update( {current_version => $second_version});

my $list = $broker->list_versions_by_source('RefSeq');
is_deeply($list,[60,61],'Both versions of test data returned');

my $source = $broker->get_current_source_by_name('RefSeq');
cmp_ok($source->current_version->revision,'==',60,'Check release revision is correct');

$source = $broker->get_source_by_name_and_version('RefSeq',61);
cmp_ok($source->versions->first->revision,'==',61,'Source fetching by specific version');

done_testing;