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
use Data::Dump::Color qw/dump/;

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Parser::Swissprot;
use Bio::EnsEMBL::Mongoose::Persistence::SolrFeeder;

my %opts = (data_location => $ARGV[0]);

my $parser = Bio::EnsEMBL::Mongoose::Parser::Swissprot->new( source_file => $opts{data_location} );
my $doc_store = Bio::EnsEMBL::Mongoose::Persistence::SolrFeeder->new();

my $buffer = 0;
my $logger = Log::Log4perl->get_logger();

$logger->info("Beginning to parse ".$opts{data_location});

while ($parser->read_record) {
    my $record = $parser->record;
    # printf "Main accession: %s, Gene name: %s, Taxon: %s\n",
    # $record->primary_accession,$record->gene_name ? $record->gene_name : '', $record->taxon_id;
    $doc_store->store_record($record);
    # $buffer++;
    # if ($buffer % 100000 == 0) {
        # $logger->info("Committing 100000 records");
        # $doc_store->commit;
    # }
};

$doc_store->commit;
$logger->info("Finished importing");