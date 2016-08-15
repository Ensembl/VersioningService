use Test::More;
use Test::Differences;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Parser::MIM;

my $reader = new Bio::EnsEMBL::Mongoose::Parser::MIM(
    source_file => "data/omim.txt",
);

$reader->read_record;
$reader->read_record; #first one is empty...
my $record = $reader->record;

is($record->id,'100050','ID extraction from TI field');
is($record->display_label, 'AARSKOG SYNDROME, AUTOSOMAL DOMINANT', 'extraction of name from TI field');
is($record->primary_accession,'100050','Accessions in first record same as ID');

$reader->read_record;
$record = $reader->record;

#%100070 AORTIC ANEURYSM, FAMILIAL ABDOMINAL, 1; AAA1
#;;ANEURYSM, ABDOMINAL AORTIC; AAA;;

is($record->id,'100070','ID of second record');
is($record->primary_accession, '100070', 'ID also assigned to accession');
is($record->display_label, 'AORTIC ANEURYSM, FAMILIAL ABDOMINAL, 1','second record display_label');
my $tags = $record->tag;
is($tags->[0],'phenotype','magic % symbol identified from second record');
ok(scalar @$tags == 1,'no other magic symbols should be found');

done_testing;