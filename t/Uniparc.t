use Test::More;
use Test::Differences;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
use Data::Dump::Color qw/dump/;
use Bio::EnsEMBL::Mongoose::Parser::Uniparc;

my $xml_reader = new Bio::EnsEMBL::Mongoose::Parser::Uniparc(
    source_file => "data/UPI0000000001.xml",
    top_tag => 'uniparc',
);

my $seq = "MGAAASIQTTVNTLSERISSKLEQEANASAQTKCDIEIGNFYIRQNHGCNLTVKNMCSADADAQLDAVLSAATETYSGLTPEQKAYVPAMFTAALNIQTSVNTVVRDFENYVKQTCNSSAVVDNKLKIQNVIIDECYGAPGSPTNLEFINTGSSKGNCAIKALMQLTTKATTQIAPKQVAGTGVQFYMIVIGVIILAALFMYYAKRMLFTSTNDKIKLILANKENVHWTTYMDTFFRTSPMVIATTDMQN";

$xml_reader->read_record;

my $record = $xml_reader->record;
is($record->accessions->[0], 'UPI0000000001', 'primary_accession check');
is($record->checksum, '28FE89850863372D', 'checksum check');
cmp_ok($record->sequence_length, '==', 250, 'sequence_length check');
cmp_ok(length($seq), '==', 250, 'other length check');
# Uniparc parser not keeping sequence, therefore no verification.
#is($record->sequence,$seq, 'Make sure sequence regex-trimming does no harm, but removes white space');

cmp_ok(scalar @{$record->count_xrefs}, '==', 0, 'No ENSEMBL xrefs in record, therefore no xrefs');
$xml_reader->read_record;
$record = $xml_reader->record;
#print ref($record->xref)."\n";
#print dump($record);
#print "Xrefs ".scalar(@{$record->xref})."\n";
cmp_ok(scalar @{$record->xref}, '==', 64, 'Second record rich in ENSEMBL xrefs');


ok(!$xml_reader->read_record, 'Check end-of-file behaviour. Reader should return false.');

done_testing;