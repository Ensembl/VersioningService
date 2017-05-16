use Modern::Perl;
use Test::More;
use Test::Differences;
use File::Path 'remove_tree';
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;
use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::HGNC';

my $source = $ENV{MONGOOSE}."/t/data/hgnc.json";
my $hgnc_reader = new Bio::EnsEMBL::Mongoose::Parser::HGNC(
    source_file => $source,
);

my $state = $hgnc_reader->read_record;

ok ($state, 'First record read correctly');
my $record = $hgnc_reader->record;
ok ($record->has_taxon_id, 'All HGNC imports have taxon');
is ($record->taxon_id, '9606', 'Hooman');
is($record->display_label, 'A1BG', 'Test ID extraction');
my @ens_ids = ();
@ens_ids = $record->grep_xrefs(sub{ $_->source eq /Ensembl/; $_});
eq_or_diff([map { $_->id } @ens_ids], [qw/NM_130786 ENSG00000121410 CCDS12976/], 'Xrefs are all successfully extracted');

$hgnc_reader->read_record;
$record = $hgnc_reader->record;
is($record->display_label, 'AAAA', 'Test ID extraction');
$hgnc_reader->read_record;
$record = $hgnc_reader->record;
is($record->display_label, 'BBBB', 'Test ID extraction');
$hgnc_reader->read_record;
$record = $hgnc_reader->record;
is($record->display_label, 'CCCC', 'Test ID extraction');
$state = $hgnc_reader->read_record;
ok(!$state, 'No further record, exit with negative state');
undef($hgnc_reader);

# now test the result of indexing
$hgnc_reader = Bio::EnsEMBL::Mongoose::Parser::HGNC->new(
    source_file => $source,
);
my $index_path = $ENV{MONGOOSE}.'/t/data/test_index';
my $indexer = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new(
  index => $index_path,
);

while ( $hgnc_reader->read_record ) {
  $record = $hgnc_reader->record;
  if ($record->has_taxon_id && ($record->has_accessions || defined $record->id)) {
    $indexer->store_record($record);
  }
}

$indexer->commit;
my $interlocutor = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => { index_location => $index_path });

my $query = 'taxon_id:9606';
$interlocutor->query($query);
my @results;
while (my $hit = $interlocutor->next_result) {
  my $record = $interlocutor->convert_result_to_record($hit);
  push @results,$record;
}

cmp_ok(scalar @results, '==', 4, 'All four records made it to the index');
is_deeply([map { $_->id } @results], [qw/HGNC:5 Cave Johnson Lemons/], 'IDs come back out of index intact');

# Delete index
remove_tree($index_path);

done_testing;
