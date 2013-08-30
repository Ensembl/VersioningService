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
    print dump($hit)."\n";
    
   #printf "Name: %s Score: %0.3f Sequence: %s\n",$hit->{gene_name},$hit->get_score,$hit->{sequence};
    foreach (keys(%$hit)) { print $_." : ". $hit->{$_}."\n"};
    print "\n"; 
}
print "###########\nFound: $total\n###########\n";