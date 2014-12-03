use strict;
use warnings;

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::Serializer::FASTA;
use Data::Dump::Color qw/dump/;
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