use strict;
use warnings;

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::Serializer::FASTA;
use Data::Dump::Color qw/dump/;
use Log::Log4perl;
use FindBin qw/$Bin/;

Log::Log4perl::init("$Bin/../conf/logger.conf");

our $fasta_writer = Bio::EnsEMBL::Mongoose::Serializer::FASTA->new();

my $query = join(' ',@ARGV);
die "Specify query string" unless $query;
#config_file => "$Bin/../conf/uniparc.conf"
my $lucy = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config_file => "$Bin/../conf/swissprot.conf");
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
#    print dump($record)."\n";
    print_as_FASTA($record);
    print "\n"; 
}
print "###########\nFound: $total\n###########\n";


sub print_as_FASTA {
    my $record = shift;
    $fasta_writer->print_record($record);
}