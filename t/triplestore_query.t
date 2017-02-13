use strict;
use Test::More;
use Test::Differences;
use Test::Deep;
use List::Compare;
use Test::MockObject::Extends;
use RDF::Trine;
use RDF::Query;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Persistence::TriplestoreQuery';

my $query_agent = Bio::EnsEMBL::Mongoose::Persistence::TriplestoreQuery->new();
my $test_data = "$ENV{MONGOOSE}/t/data/test_graph.ttl";

our $store = RDF::Trine::Store::Memory->new();
our $model = RDF::Trine::Model->new($store);
my $parser = RDF::Trine::Parser->new('turtle');
$parser->parse_file_into_model("http://everything/",$test_data,$model);
ok(1, 'Test data loaded');

# Graph is a simple a->x->b->x2->c with Subject labels

cmp_ok($model->size, '==', 9, "Check all triples have been imported");
$query_agent = Test::MockObject::Extends->new($query_agent);


my $mock_query = sub {
  my $self = shift;
  my $query = shift;
  my $query_obj = RDF::Query->new($query);
  my $iterator = $query_obj->execute($model);
  $query_agent->result_set($iterator);
  return $iterator;
};

$query_agent->mock(query => $mock_query);
$query_agent->graph("http://everything/");
# Prove basic querying is functional
$query_agent->query(sprintf qq(%s\nSELECT ?s ?p ?o {
    ?s ?p ?o .
    }), $query_agent->compatible_name_spaces());

my $counter = 0;
while (my $hit = $query_agent->result_set->next) {
  $counter++;
  # note $hit->{s}, $hit->{p}, $hit->{o};
}
cmp_ok($counter, '==', 9, 'All triples extracted via generic query');


# Prove we can ask sensible questions of an xref graph

my $id_list = $query_agent->recurse_xrefs('Subject a');
is_deeply($id_list, ['Subject b','Subject c'], 'a links to b and c');

my $id_list = $query_agent->recurse_xrefs('Subject b');
is_deeply($id_list, ['Subject c'], 'b links only to a');

my $id_list = $query_agent->get_all_linking_xrefs('Subject c');
is_deeply($id_list, ['Subject a','Subject b'], 'c is linked to by a and b');

done_testing();
