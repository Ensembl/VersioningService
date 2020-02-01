# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
use Config::General;

my $data_location = '/Users/ktaylor/mongoose/t/hgnc.json';


Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Parser::HGNC;
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;

my $parser = Bio::EnsEMBL::Mongoose::Parser::HGNC->new( source_file => $data_location );

my $buffer = 0;
my $logger = Log::Log4perl->get_logger();

use Data::Dumper;

while ($parser->read_record) {
    my $record = $parser->record;
    print Dumper $record;
    printf "Main accession: %s, Gene name: %s, Taxon: %s\n",
         $record->primary_accession,$record->entry_name ? $record->entry_name : '', 9606;
    $buffer++;
    
    if ($record->has_taxon_id && ($record->has_accessions || defined $record->id)) {
        print "WOOOOOOOOOOO!!!!!!\n\n\n";
    }
    <STDIN>;
};
$logger->info("Finished importing");
