use strict;
use warnings;

use Lucy::Search::IndexSearcher;
use Data::Dump::Color qw/dump/;

my $query = shift;
die "Specify query string" unless $query;

my $lucy = Lucy::Search::IndexSearcher->new(
    index => "/Users/ktaylor/projects/data/mongoose.index/"
);

my $hits = $lucy->hits(
    query => $query,
);


print "Found: ".$hits->total_hits()."\n";
while (my $hit = $hits->next) {
    print dump($hit)."\n";
    #printf "%s %0.3f %s\n",$hit->{gene_name},$hit->get_score,$hit->{sequence};
    foreach (keys(%$hit)) { print $_." : ". $hit->{$_}."\n"} 
}