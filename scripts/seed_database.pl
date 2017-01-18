# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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

use Bio::EnsEMBL::Versioning::Broker;
use Log::Log4perl;

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $broker = Bio::EnsEMBL::Versioning::Broker->new(create => 1,config_file => "$ENV{MONGOOSE}/conf/manager.conf");

$broker->add_new_source('Uniprot/SWISSPROT','Uniprot',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtSwissProt','Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster');
$broker->add_new_source('UniParc','Uniprot',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtUniParc','Bio::EnsEMBL::Mongoose::Parser::Uniparc');
$broker->add_new_source('Uniprot/SPTREMBL','Uniprot',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtTrembl','Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster');
$broker->add_new_source('RefSeq','RefSeq',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq','Bio::EnsEMBL::Mongoose::Parser::RefSeq');
$broker->add_new_source('MIM','MIM',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM','Bio::EnsEMBL::Mongoose::Parser::MIM');
$broker->add_new_source('mim2gene','MIM',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM2GeneMedGen','Bio::EnsEMBL::Mongoose::Parser::MIM2GeneMedGen');
$broker->add_new_source('HGNC','HGNC',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HGNC','Bio::EnsEMBL::Mongoose::Parser::HGNC');
$broker->add_new_source('EntrezGene','EntrezGene',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::EntrezGene','Bio::EnsEMBL::Mongoose::Parser::EntrezGene');
$broker->add_new_source('Reactome','Reactome',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::Reactome','Bio::EnsEMBL::Mongoose::Parser::Reactome');
$broker->add_new_source('ArrayExpress','ArrayExpress',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::ArrayExpress','Bio::EnsEMBL::Mongoose::Parser::ArrayExpress');
$broker->add_new_source('HPA','HPA',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HPA','Bio::EnsEMBL::Mongoose::Parser::HPA');
$broker->add_new_source('UCSC','UCSC',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UCSC','Bio::EnsEMBL::Mongoose::Parser::UCSC');
$broker->add_new_source('MiRBase','MiRBase',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MiRBase','Bio::EnsEMBL::Mongoose::Parser::MiRBase');
$broker->add_new_source('DBASS','DBASS',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS','Bio::EnsEMBL::Mongoose::Parser::DBASS');
$broker->add_new_source('RGD','RGD',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RGD','Bio::EnsEMBL::Mongoose::Parser::RGD');
$broker->add_new_source('Xenbase','Xenbase',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::Xenbase','Bio::EnsEMBL::Mongoose::Parser::Xenbase');

print "Created basic Xref working set of sources. Now enable the update pipeline to allow it to download the first copy of each source\n";
