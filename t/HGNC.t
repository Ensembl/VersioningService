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
#print dump($record);
my $accessions = $record->accessions;
note(scalar @$accessions);
is($record->primary_accession, 'HGNC:1101', 'primary_accession check');
is($record->display_label, 'BRCA2', 'display_label check');
is($record->gene_name, 'breast cancer 2, early onset', 'Gene name check');
my $xrefs = $record->xref;
is($xrefs->[0]->source, 'RefSeq', 'Xref source check');
is($xrefs->[0]->id, 'NM_000059', 'Xref id check');
is($xrefs->[1]->source, 'Ensembl', 'Xref source check 2');
is($xrefs->[2]->source, 'CCDS', 'Xref source check 3');
is($xrefs->[3]->source, 'LRG_HGNC_notransfer', 'Xref source check 4');
is(scalar(@$xrefs), 4, 'All xrefs accounted for');
my $synonyms = $record->synonyms;
is($synonyms->[0], 'FAD', 'Synonym check');
is(scalar(@$synonyms), 6, 'All synonyms accounted for');
$hgnc_reader->read_record;
$hgnc_reader->read_record;
ok(!$hgnc_reader->read_record, 'Check end-of-file behaviour. Reader should return false.');

done_testing;
