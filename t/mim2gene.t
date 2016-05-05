use Test::More;
use Test::Differences;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Parser::MIM2Gene;

my $reader = new Bio::EnsEMBL::Mongoose::Parser::MIM2Gene(
    source_file => "data/mim2gene.txt",
);

$reader->read_record; #first one is empty...
my $record = $reader->record;

is($record->id,'100050','ID extraction from column 1');
$reader->read_record;
$record = $reader->record;
is($record->id,'100070','ID of second record');

my @sources = $record->map_xrefs(sub {$_->source});
is_deeply(\@sources, ['EntrezGene'], 'Right number of xref sources correctly set');
my @xref_ids = $record->map_xrefs(sub {$_->id});
is_deeply(\@xref_ids, ['100329167'], 'Right number of xref accessions correctly set');

while ($reader->read_record()) {
  $record = $reader->record;
  if ($record->id eq '100500') {
    cmp_ok($record->count_xrefs, '==', 0, 'Moved/removed record has no xrefs');
  }
}
ok(1, 'Reached end of mim2gene.txt without dying');

done_testing;