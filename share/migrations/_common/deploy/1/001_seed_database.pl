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
use DBIx::Class::Migration::RunScript;

migrate {
  my $self = shift;
  my $source_rs = $self->schema->resultset('Source');
  $source_rs->create({
    name => 'Uniprot/SWISSPROT',
    source_groups => { name => 'Uniprot'},
    active => 1,
    downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtSwissProt',
    parser => 'Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster'
    } );

  $source_rs->create({
    name => 'UniParc',
    source_groups => { name => 'Uniprot' },
    active => 0,
    downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtUniParc',
    parser => 'Bio::EnsEMBL::Mongoose::Parser::Uniparc'
  });

  $source_rs->create({
      name => 'Uniprot/SPTREMBL',
      source_groups => { name => 'Uniprot' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtTrembl',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster'
  });

  $source_rs->create({
      name => 'RefSeq',
      source_groups => { name => 'RefSeq' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::RefSeq'
  });

  $source_rs->create({
      name => 'MIM',
      source_groups => { name => 'MIM' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::MIM'
  });

  $source_rs->create({
      name => 'mim2gene',
      source_groups => { name => 'MIM' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM2GeneMedGen',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::MIM2GeneMedGen'
  });

  $source_rs->create({
      name => 'HGNC',
      source_groups => { name => 'HGNC' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HGNC',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::HGNC'
  });

  $source_rs->create({
      name => 'EntrezGene',
      source_groups => { name => 'EntrezGene' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::EntrezGene',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::EntrezGene'
  });
  $source_rs->create({
      name => 'Reactome',
      source_groups => { name => 'Reactome' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::Reactome',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::Reactome'
  });
  $source_rs->create({
      name => 'ArrayExpress',
      source_groups => { name => 'ArrayExpress' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::ArrayExpress',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::ArrayExpress'
  });

  $source_rs->create({
      name => 'HPA',
      source_groups => { name => 'HPA' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HPA',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::HPA'
  });

  $source_rs->create({
      name => 'UCSC',
      source_groups => { name => 'USCS' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::USCS',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::USCS'
  });
  $source_rs->create({
      name => 'MiRBase',
      source_groups => { name => 'MiRBase' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MiRBase',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::MiRBase'
  });
  $source_rs->create({
      name => 'DBASS',
      source_groups => { name => 'DBASS' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::DBASS',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::DBASS'
  });
  $source_rs->create({
      name => 'RGD',
      source_groups => { name => 'RGD' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RGD',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::RGD'
  });
  $source_rs->create({
      name => 'Xenbase',
      source_groups => { name => 'Xenbase' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::Xenbase',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::Xenbase'
  });

  $source_rs->create({
      name => 'JGI',
      source_groups => { name => 'JGI' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::JGI',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::JGI'
  });
  $source_rs->create({
      name => 'VGNC',
      source_groups => { name => 'VGNC' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::VGNC',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::VGNC'
  });
  $source_rs->create({
      name => 'ZFIN',
      source_groups => { name => 'ZFIN' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::ZFIN',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::ZFIN'
  });
  $source_rs->create({
      name => 'RNAcentral',
      source_groups => { name => 'RNAcentral' },
      active => 1,
      downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RNAcentral',
      parser => 'Bio::EnsEMBL::Mongoose::Parser::RNAcentral'
  });

};