# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Demo script to demonstrate "Mfetch-like" behaviour of the Swissprot index.
# Takes a species name and writes out FASTA for that species.

use strict;
use warnings;

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::Serializer::FASTA;
use Bio::EnsEMBL::Mongoose::IndexSearch;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use Data::Dump::Color qw/dump/;
use Log::Log4perl;

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $query = shift;
die "Specify query string e.g. 'mus musculus'" unless $query;

my $mfetcher = Bio::EnsEMBL::Mongoose::IndexSearch->new();
$mfetcher->work_with_index(source => 'Swissprot');

my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    species_name => $query
    # ids => ['Q13878'],
    # id_type => 'accessions',
    # evidence_level => 1,
    # taxons => [9606],
);
$mfetcher->query_params($params);

$mfetcher->get_records_by_species_name();

