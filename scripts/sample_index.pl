# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Versioning::Broker;
use Bio::EnsEMBL::Mongoose::Serializer::FASTA;
use Bio::EnsEMBL::Mongoose::Serializer::JSON;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Log::Log4perl;
use IO::File;
use Data::Dumper;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
my $handle;
open $handle, ">&STDOUT";

our $writer = Bio::EnsEMBL::Mongoose::Serializer::JSON->new(handle => $handle);

my $source = shift;

my $broker = Bio::EnsEMBL::Versioning::Broker->new();
my $valid_source_list = $broker->get_active_sources;
my @source_list = map { $_->name } @$valid_source_list;
print "Sources available: ".join(',',@source_list)."\n";
die "No source provided" unless $source;
my @matches = grep { $_->name eq $source } @$valid_source_list;
if (@matches < 1) {
  die "Requested source not in available list";
}
my $source_obj = $broker->get_source($source);
my $index = $source_obj->current_version;
if (!$index) { die "No current index associated with $source" }
printf "Initialised index at %s, with %s records",$index->index_uri,$index->record_count;
print "Sample results follow\n";

my $lucy = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => { index_location => $index->index_uri });
my $query = "taxon_id:9606";
$lucy->query($query);
my $total = 0;
print "###########\n";
my $limit = 120;


while ((my $hit = $lucy->next_result) && $limit > 0) {
    $limit--;
    $total++;
    #printf "Name: %s Score: %0.3f Sequence: %s\n",$hit->{gene_name},$hit->get_score,$hit->{sequence};
#    foreach (keys($hit)) {
#        print $_."\n";
#    }
    my $record = $lucy->convert_result_to_record($hit);
#    print $record->primary_accession."\n";
#    print Dumper $record;
    $writer->print_record($record); 
}
print "###########\nDumped: $total\n###########\n";

