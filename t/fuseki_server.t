
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
  my $fuseki = Bio::EnsEMBL::RDF::FusekiWrapper->new();
  my $server_url = $fuseki->start_server();
  note "Server started on $server_url?";
  $fuseki->load_data(["$Bin/data/test_graph.ttl"],'xref');
  note "Data loaded";
  my $row_count = 0;
  my $sparql = "SELECT ?s ?p ?o FROM <${server_url}xref> WHERE { ?s ?p ?o . }";
  $fuseki->query($sparql) if $fuseki->background_process_alive;
  while (my $row = $fuseki->sparql->next_result) {
    $row_count++;
  }
  
  cmp_ok($row_count, '==', 9, 'Data was both loaded and queried');
  $fuseki->delete_data($server_url.$fuseki->graph_name);
  $fuseki->query($sparql);
  $row_count = 0;
  while (my $row = $fuseki->sparql->next_result) {
    $row_count++;
  }

  cmp_ok($row_count, '==', 0, 'Model successfully deleted');
  $fuseki->stop_background_process;

  throws_ok(sub {$fuseki->query($sparql)}, 'Bio::EnsEMBL::Mongoose::DBException', 'Querying a shutdown triplestore throws a DBException');
}

done_testing();
