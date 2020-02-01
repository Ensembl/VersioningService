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

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::Serializer::FASTA;
use Log::Log4perl;
use IO::File;

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
my $handle;
open $handle, ">&STDOUT";

our $fasta_writer = Bio::EnsEMBL::Mongoose::Serializer::FASTA->new(handle => $handle);

my $query = join(' ',@ARGV);
die "Specify query string" unless $query;
#config_file => "$Bin/../conf/uniparc.conf"
my $lucy = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => { index_location => '/Users/ktaylor/projects/mongoose/Uniprot/UniProtSwissProt/2014_04/index/' });
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
    print $record->primary_accession."\n";
    print dump($record)."\n";
    print_as_FASTA($record);
    print "\n"; 
}
print "###########\nFound: $total\n###########\n";


sub print_as_FASTA {
    my $record = shift;
    $fasta_writer->print_record($record);
}
