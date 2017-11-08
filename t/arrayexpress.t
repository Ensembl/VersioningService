use strict;
use Test::More;
use Test::Differences;
use Test::Deep;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::ArrayExpress';

my $reader = new Bio::EnsEMBL::Mongoose::Parser::ArrayExpress(
    source_file => "$ENV{MONGOOSE}/t/data/homo_sapiens.ensgene.tsv",
);

my $num_of_records = 0;
#first record
$reader->read_record;
my $record = $reader->record;
$num_of_records++;
is($record->id,'ENSG00000000003','ID extraction from first record');

#next record
$reader->read_record;
$record = $reader->record;
$num_of_records++;
is($record->id,'ENSG00000000005','ID extraction from second record');

#check xrefs
my $expected_xref = [
                             bless( {
                                      source => 'HGNC',
                                      creator => 'ArrayExpress',
                                      active => 1,
                                      id => 'TNMD'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref'),
                             bless( {
                                      source => 'entrezgene',
                                      creator => 'ArrayExpress',
                                      active => 1,
                                      id => '64102'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                             bless( {
                                      source => 'refseq',
                                      creator => 'ArrayExpress',
                                      active => 1,
                                      id => 'NM_022144'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                             bless( {
                                      source => 'refseq',
                                      creator => 'ArrayExpress',
                                      active => 1,
                                      id => 'NP_071427'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                             bless( {
                                      source => 'unigene',
                                      creator => 'ArrayExpress',
                                      active => 1,
                                      id => 'Hs.132957'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                             bless( {
                                      source => 'Uniprot/SWISSPROT',
                                      creator => 'ArrayExpress',
                                      active => 1,
                                      id => 'Q9H2S6'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                             bless( {
                                      source => 'interpro',
                                      creator => 'ArrayExpress',
                                      active => 1,
                                      id => 'IPR007084'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                             bless( {
                                      source => 'ensembl',
                                      creator => 'ArrayExpress',
                                      active => 1,
                                      id => 'ENSG00000000005'
                                    }, 'Bio::EnsEMBL::Mongoose::Persistence::RecordXref' ),
                           ];

my $all_xrefs = $record->xref;
isa_ok($all_xrefs, 'ARRAY' );
cmp_deeply($all_xrefs, $expected_xref, "Got back right xrefs");

#check synonyms
my @expected = qw(BRICD4 ChM1L TEM myodulin tendin);
my $got = $record->synonyms;
isa_ok($got, 'ARRAY' );
cmp_deeply($got, \@expected, "Got back right synonym");

#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  $num_of_records++;
}
ok(1, 'Reached end of homo_sapiens.ensgene.tsv without dying');
ok(10 == $num_of_records, "Read all the $num_of_records records from the file successfully");

#test ensprotein files
$num_of_records = 0;
$reader = new Bio::EnsEMBL::Mongoose::Parser::ArrayExpress(
    source_file => "$ENV{MONGOOSE}/t/data/homo_sapiens.ensprotein.tsv",
);
#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  $num_of_records++;
}
ok(1, 'Reached end of homo_sapiens.ensprotein.tsv without dying');
ok(10 == $num_of_records, "Read all the $num_of_records records from the file successfully");
is($record->id,'ENSP00000002829','ID extraction from last record');


#test enstranscript files
$num_of_records = 0;
$reader = new Bio::EnsEMBL::Mongoose::Parser::ArrayExpress(
    source_file => "$ENV{MONGOOSE}/t/data/homo_sapiens.enstranscript.tsv",
);
#read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  $num_of_records++;
}
ok(1, 'Reached end of homo_sapiens.enstranscript.tsv without dying');
ok(10 == $num_of_records, "Read all the $num_of_records records from the file successfully");
is($record->id,'ENST00000002829','ID extraction from last record');


done_testing;
