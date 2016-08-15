use Test::More;
use Test::Differences;
use Data::Dumper;
use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
use Bio::EnsEMBL::Mongoose::Parser::HGNC;


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
done_testing;
