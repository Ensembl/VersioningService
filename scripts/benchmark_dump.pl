# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
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

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::IndexSearcher;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use IO::File;

my $fh = IO::File->new('dirty_great_file.fa','w');

my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    #evidence_level => 1,
    taxons => [40674],
);

my $mfetcher = Bio::EnsEMBL::Mongoose::IndexSearcher->new(
    storage_engine_conf => "$ENV{MONGOOSE}/conf/swissprot.conf",
    query_params => $params,
    handle => $fh,
);

$mfetcher->get_sequence_including_descendants;
