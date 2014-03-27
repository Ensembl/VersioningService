use Test::More;
use Test::Differences;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
use Data::Dump::Color qw/dump/;
use Bio::EnsEMBL::Mongoose::Parser::Refseq;


my $source = $ENV{MONGOOSE}."/t/data/XM_005579308.gbff";
my $ref_seq_reader = Bio::EnsEMBL::Mongoose::Parser::Refseq->new(
    source_file => $source,
);

$ref_seq_reader->read_record;

my $record = $ref_seq_reader->record;
# print dump($record);
my $accessions = $record->accessions;
# note(scalar @$accessions);
is($record->accessions->[0], 'XM_005579308', 'primary_accession check');
cmp_ok($record->sequence_length, '==', 6102, 'sequence_length check');
is($record->taxon_id, '9539','Taxon correctly extracted');
is($record->id, 'XM_005579308','ID correctly extracted');
is($record->gene_name, 'CTSC','Gene name correctly extracted');
$ref_seq_reader->read_record;
$record = $ref_seq_reader->record;
#print ref($record->xref)."\n";
#print dump($record);
#print "Xrefs ".scalar(@{$record->xref})."\n";
ok(!$ref_seq_reader->read_record, 'Check end-of-file behaviour. Reader should return false.');

done_testing;