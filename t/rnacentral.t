use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Parser::RNAcentral;
use JSON;
use Data::Dumper;

my $reader = new Bio::EnsEMBL::Mongoose::Parser::RNAcentral(
    source_file => "$ENV{MONGOOSE}/t/data/rnacentral.json",
);

my $num_of_records = 0;

#first record
$reader->read_record;
$record = $reader->record;
$num_of_records++;

my $expected_record_id = "URS000000000B_77133";
my $expected_record_taxon_id = "77133";
my $expected_record_checksum = "030c96880939e83fabd488c3c8f2db42";
my $expected_record_sequence_length = "464";

ok($expected_record_id eq $record->id, "Got the right rnacentral_id");
ok($expected_record_taxon_id eq $record->taxon_id, "Got the right taxon_id");
ok($expected_record_checksum eq $record->checksum, "Got the right checksum");
ok($expected_record_sequence_length eq $record->sequence_length, "Got the right sequence_length");

#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  $num_of_records++;
}

$expected_record_id = "URS0000000055_9606";
$expected_record_taxon_id = "9606";
$expected_record_checksum = "030d71b4e7bcb65583d4af70e3110940";
$expected_record_sequence_length = "699";

ok($expected_record_id eq $record->id, "Got the right rnacentral_id");
ok($expected_record_taxon_id eq $record->taxon_id, "Got the right taxon_id");
ok($expected_record_checksum eq $record->checksum, "Got the right checksum");
ok($expected_record_sequence_length eq $record->sequence_length, "Got the right sequence_length");

ok($num_of_records == 3, "Got all 3 records");

done_testing;
