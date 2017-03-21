use Test::More;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::UniGene';

my $reader = new Bio::EnsEMBL::Mongoose::Parser::UniGene(
    source_file => "$ENV{MONGOOSE}/t/data/9606_Hs.seq.uniq.gz",
);

my $num_of_records = 0;
#first record
$reader->read_record;
$record = $reader->record;
$num_of_records++;

is($record->id,'Hs.2','ID extracted from first record '.$record->id);
is($record->sequence_length,'1344','sequence_length for first record '.$record->sequence_length);
is($record->checksum,'efddd0fa7cbdd6be4cc1625beac1e963','checksum for first record '.$record->checksum);
is($record->cds_start,'105','cds_start extracted from first record '.$record->cds_start);
is($record->cds_end,'977','cds_end extracted from first record '.$record->cds_end);
is($record->display_label,'Hs.2','display_label extracted from first record '.$record->display_label);
is($record->taxon_id,'9606','taxon_id is set '.$record->taxon_id);

##next record
$reader->read_record;
$record = $reader->record;
$num_of_records++;
is($record->id,'Hs.4','ID extraction from second record');
is($record->checksum,'64bff0fb86a8f2dec06351cde0bbe5e4','checksum for second record '.$record->checksum);
is($record->sequence_length,'4080','sequence_length for second record '.$record->sequence_length);

#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  $num_of_records++;
}

ok(1, 'Reached end of Hs.seq.uniq.gz without dying');
ok(5 == $num_of_records, "Read all the 5 records from the file successfully");

done_testing;
