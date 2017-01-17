
use strict;
use Test::More;
use Test::Exception;
use Test::Differences;
use Bio::EnsEMBL::RDF::FusekiWrapper;

note "Starting Fuseki Java process";
my $fuseki = Bio::EnsEMBL::RDF::FusekiWrapper->new();
$fuseki->start_server();
note "Server started?";
$fuseki->load_data(['data/test_graph.ttl']);
note "Data loaded";
my $row_count = 0;
my $sparql = 'SELECT ?s ?p ?o WHERE { ?s ?p ?o . }';
$fuseki->query($sparql) if $fuseki->background_process_alive;
while (my $row = $fuseki->sparql->next_result) {
  $row_count++;
}

cmp_ok($row_count, '==', 9, 'Data was both loaded and queried');

$fuseki->stop_background_process;

throws_ok(sub {$fuseki->query($sparql)}, 'Bio::EnsEMBL::Mongoose::DBException', 'Querying a shutdown triplestore throws a DBException');

done_testing();