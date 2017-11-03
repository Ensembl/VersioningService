
use strict;
use Test::More;
use Test::Exception;
use Test::Differences;

use FindBin qw/$Bin/;

use_ok 'Bio::EnsEMBL::RDF::FusekiWrapper';

SKIP: {
  skip "Cannot test Fuseki integration unless Fuseki is available", 2
    unless defined $ENV{FUSEKI_HOME};
  
  note "Starting Fuseki Java process";
  my $fuseki = Bio::EnsEMBL::RDF::FusekiWrapper->new(heap => 2, graph_name => 'xref');
  my $server_url = $fuseki->start_server();
  note "Server started on $server_url?";
  sleep 2;
  $fuseki->load_data(["$Bin/data/test_graph.ttl"],'xref');
  my $graph_url = $fuseki->graph_url;
  note "Data loaded";
  note $graph_url;
  my $row_count = 0;
  my $sparql = "SELECT ?s ?p ?o FROM <${graph_url}> WHERE { ?s ?p ?o . }";
  my $iterator;
  $iterator = $fuseki->query($sparql) if $fuseki->background_process_alive;
  while (my $row = $iterator->next) {
    $row_count++;
  }
  
  cmp_ok($row_count, '==', 9, 'Data was both loaded and queried');
  $fuseki->delete_data($fuseki->graph_name);
  my $result = $fuseki->query($sparql);
  $row_count = 0;
  while (my $row = $result->next) {
    $row_count++;
  }

  cmp_ok($row_count, '==', 0, 'Model successfully deleted');
  $fuseki->stop_background_process;

  throws_ok(sub {$fuseki->query($sparql)}, 'Bio::EnsEMBL::Mongoose::DBException', 'Querying a shutdown triplestore throws a DBException');
}

done_testing();
