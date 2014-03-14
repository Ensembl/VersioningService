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

# use Test::More;
# use Test::Exception;

use Bio::EnsEMBL::Versioning::DB;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
-host => '127.0.0.1',
-species => 'multi',
-group => 'versioning',
-user => 'ensadmin',
-pass => 'ensembl',
-port => 3350,
-dbname => 'versioning_db'
);
Bio::EnsEMBL::Versioning::DB->register_DBAdaptor($dba);

require Bio::EnsEMBL::Versioning::Manager::Version;
require Bio::EnsEMBL::Versioning::Manager::Process;
require Bio::EnsEMBL::Versioning::Manager::Source;
require Bio::EnsEMBL::Versioning::Manager::SourceGroup;
require Bio::EnsEMBL::Versioning::Manager::Run;

my $uniprot_source = Bio::EnsEMBL::Versioning::Object::Source->new(name => 'UniProtSwissprot', parser => 'UniProtParser');
$uniprot_source->source_group(name => 'UniProtGroup');
$uniprot_source->save();
my $uniprot_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '2013_12', record_count => 49243530, uri => '/lustre/scratch110/ensembl/mr6/Uniprot/203_12/uniprot.txt');
$uniprot_version->source($uniprot_source);
$uniprot_version->save();

my $refseq_source = Bio::EnsEMBL::Versioning::Object::Source->new(name => 'RefSeqPeptide', parser => 'RefSeqParser');
$refseq_source->source_group(name => 'RefSeqGroup');

my $refseq_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '61', record_count => 49243530, uri => '/lustre/scratch110/ensembl/mr6/RefSeq/61/refseq.txt');
$refseq_version->source($refseq_source);

my $second_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '60', record_count => 40000, uri => '/lustre/scratch110/ensembl/mr6/RefSeq/61/refseq.txt');
$second_version->source($refseq_source);
$second_version->save();
$refseq_version->save();
$refseq_source->current_version($second_version->version_id);
$refseq_source->save;