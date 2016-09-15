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

# Demo script to demonstrate "Mfetch-like" behaviour of the Swissprot index.
# Takes a species name and writes out FASTA for that species.

use strict;
use warnings;

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::IndexSearch;
use Bio::EnsEMBL::Versioning::Broker;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use IO::File;
use File::Spec;
use Try::Tiny;
use Log::Log4perl;
use MongooseHelper;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
use List::Compare;

my $opts = MongooseHelper->new_with_options();

my $broker = Bio::EnsEMBL::Versioning::Broker->new();

my $valid_source_list = $broker->get_active_sources;
my @source_names = map { $_->name } @$valid_source_list;
print "Sources available: ".join(',',@source_names)."\n";
my $proposed_sources = $opts->source_list;

die "No source provided" unless $opts->source_list;
my $comp = List::Compare->new($opts->source_list,\@source_names);
my @final_source_list = $comp->get_union();
print "Selected sources: ".join(',',@final_source_list)."\n";

my $searcher = Bio::EnsEMBL::Mongoose::IndexSearch->new(
  output_format => 'RDF',
  storage_engine_conf_file => $ENV{MONGOOSE}.'/conf/manager.conf',
  species => $opts->species,
);
my $base_path = $opts->dump_path;
$base_path ||= '';
foreach my $source (@final_source_list) {
  my $fh = IO::File->new(File::Spec->catfile($base_path,$source.'.ttl'), 'w');
  try {
      $searcher->handle($fh);
      $searcher->work_with_index(source => $source);
      $searcher->_select_writer;
      # my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
      #    taxons => [9606],
      # );
      # $searcher->query_params($params);

      $searcher->get_records();      
    } catch {
      warn $_;
      $fh->close;
    };
  
}