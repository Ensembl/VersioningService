use Test::More;
use Test::Differences;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
use Bio::EnsEMBL::Mongoose::Parser::HGNC;


my $source = $ENV{MONGOOSE}."/t/data/hgnc.txt";
my $hgnc_reader = new Bio::EnsEMBL::Mongoose::Parser::HGNC(
    source_file => $source,
);

$hgnc_reader->read_record;

my $record = $hgnc_reader->record;
print "Fetching first $record\n";
#print dump($record);
my $accessions = $record->accessions;
note(scalar @$accessions);
is($record->primary_accession, 'HGNC:5', 'primary_accession check');
is($record->display_label, 'A1BG', 'display_label check');
my $xrefs = $record->xref;
is($record->xref->[0]->source, 'RefSeq', 'Xref source check');
is($record->xref->[0]->id, 'NM_130786', 'Xref id check');
$hgnc_reader->read_record;
$hgnc_reader->read_record;
ok(!$hgnc_reader->read_record, 'Check end-of-file behaviour. Reader should return false.');

done_testing;
