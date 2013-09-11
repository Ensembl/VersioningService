use strict;
use warnings;

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Data::Dump::Color qw/dump/;
use Log::Log4perl;
use FindBin qw/$Bin/;

Log::Log4perl::init("$Bin/../conf/logger.conf");


my $query = join(' ',@ARGV);
die "Specify query string" unless $query;

my $lucy = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new();
$lucy->query($query);
my $total = 0;
print "###########\n";
my $limit = 120;


while ((my $hit = $lucy->next_result) && $limit > 0) {
    $limit--;
    $total++;
    
    #printf "Name: %s Score: %0.3f Sequence: %s\n",$hit->{gene_name},$hit->get_score,$hit->{sequence};
   
    my $record = $lucy->convert_result_to_record($hit);
    print $record->primary_accession."\n";
    #print dump($record)."\n";
    
    print "\n"; 
}
print "###########\nFound: $total\n###########\n";