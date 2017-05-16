use Modern::Perl;
use Test::More;
use Test::Differences;
use Test::Deep;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok  'Bio::EnsEMBL::Mongoose::Parser::Reactome';

my $reader = new Bio::EnsEMBL::Mongoose::Parser::Reactome(
    source_file => "$ENV{MONGOOSE}/t/data/reactome.txt",
);

my $num_of_records = 0;
#first record
$reader->read_record;
my $record = $reader->record;
$num_of_records++;
is($record->id,'R-HSA-162699','ID extraction from first record');


#next record
$reader->read_record;
$record = $reader->record;
$num_of_records++;
is($record->id,'R-HSA-163125','ID extraction from second record');

my $all_xrefs = $record->xref;
isa_ok($all_xrefs, 'ARRAY' );

my $expected_xref = [
                    bless( {
                      'source' => 'Ensembl',
                      'creator' => 'Reactome',
                      'active' => 1,
                      'id' => 'ENSG00000000419'
                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' )
                    ];
cmp_deeply($all_xrefs, $expected_xref, "Got back right xrefs");

#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  $num_of_records++;
 
}
ok(1, 'Reached end of reactome.txt without dying');
ok(30 == $num_of_records, "Read all the $num_of_records records from the file successfully");

#checking the last record 
is($record->id,'R-ATH-556833','ID extraction from last record');

$all_xrefs = $record->xref;
isa_ok($all_xrefs, 'ARRAY' );

$expected_xref = [
                 bless( {
                   'source' => 'Uniprot',
                   'creator' => 'Reactome',
                   'active' => 1,
                   'id' => 'Q70DU8'
                 }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' )
                 ];
cmp_deeply($all_xrefs, $expected_xref, "Got back right xrefs");


#get the first xref and check if the object is right
my $first_xref = shift $all_xrefs;
isa_ok($first_xref, "Bio::EnsEMBL::Mongoose::Persistence::RecordXref");

done_testing;