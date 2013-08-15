use strict;
use warnings;

use Lucy::Search::IndexSearcher;
use Lucy::Search::QueryParser;
use Data::Dump::Color qw/dump/;

my $query = join(' ',@ARGV);
die "Specify query string" unless $query;

my $lucy = Lucy::Search::IndexSearcher->new(
    index => "/Users/ktaylor/projects/data/mongoose.index/"
);
my $qp = Lucy::Search::QueryParser->new(
    schema => $lucy->get_schema,
    default_boolop => 'AND',
);
$qp->set_heed_colons(1);
my $query_obj = $qp->parse($query);


my $hits = $lucy->hits(
    query => $query_obj,
);

print "###########\n";
while (my $hit = $hits->next) {
    #print dump($hit)."\n";
    #printf "%s %0.3f %s\n",$hit->{gene_name},$hit->get_score,$hit->{sequence};
    foreach (keys(%$hit)) { print $_." : ". $hit->{$_}."\n"};
    print "\n"; 
}
print "###########\nFound: ".$hits->total_hits()."\n###########\n";