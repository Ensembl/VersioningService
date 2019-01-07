# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

use Modern::Perl;

use MongooseHelper;
use IO::File;
use Log::Log4perl;
use Bio::EnsEMBL::Mongoose::IndexSearch;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;

my $opts = MongooseHelper->new_with_options();

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $neat_species = $opts->species;
$neat_species =~ s/\s+/_/g;
my $fh = IO::File->new(sprintf "%s/%s_triples.ttl",$opts->dump_path,$neat_species,'w');

my $extractor = Bio::EnsEMBL::Mongoose::IndexSearch->new(
  handle => $fh, 
  species => $opts->species, 
  output_format => 'RDF', 
  storage_engine_conf_file => $ENV{MONGOOSE}.'/conf/manager.conf'
);


my @source_list = @{ $opts->source_list }; #qw/Swissprot MIM mim2gene HGNC/;
for my $source (@source_list) {
  $extractor->work_with_index(source =>$source);
  $extractor->get_records;
}
