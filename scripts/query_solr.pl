use LWP::Simple;
use JSON;
use Bio::EnsEMBL::Mongoose::Persistence::SolrFeeder;

my $solr = Bio::EnsEMBL::Mongoose::Persistence::SolrFeeder->new();

my $url = 'http://127.0.0.1:8983/solr/swissprot_mongoose/select?q=id%3AQ9KV26&wt=json&indent=false';
my $content = get($url);
my $hash = decode_json($content);

foreach my $doc( @{$hash->{response}->{docs}}) {
  my $record = $solr->decompress_json($doc->{json});
  use Data::Dumper; warn Dumper $record;
}