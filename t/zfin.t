use Modern::Perl;
use Test::More;
use Test::Differences;
use File::Path 'remove_tree';
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;
use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::ZFIN';

my $source = $ENV{MONGOOSE}."/t/data/aliases.txt";
my $zfin_reader = new Bio::EnsEMBL::Mongoose::Parser::ZFIN(
    source_file => $source,
);

my $state = $zfin_reader->read_record;

ok ($state, 'First record read correctly');
my $record = $zfin_reader->record;
ok ($record->has_taxon_id, 'All ZFIN imports have a taxon');
is ($record->taxon_id, '7955', 'Zebrafish taxon');
is($record->display_label, 'c1033', 'First symbol extracted');

use Data::Dumper;
is_deeply($record->synonyms, [qw/Df(LG03) Df(LG03)c1033 c1033/], 'Synonyms aggregated from multiple rows');

$zfin_reader->read_record;
$record = $zfin_reader->record;
is($record->id,'ZDB-ALT-000405-2', 'Record ID match');
is($record->display_label, 'w15','Preferred display label');
is_deeply($record->synonyms, [qw/Df(Chr24:reck)w15 w15/], 'Synonyms all there');
is($record->taxon_id,'7955','Still a fish');

ok(!$zfin_reader->read_record,'Test reading beyond end');

### Point at uniprot file
$source = $ENV{MONGOOSE}."/t/data/uniprot.txt";
$zfin_reader = new Bio::EnsEMBL::Mongoose::Parser::ZFIN(
    source_file => $source,
);

my @records;
while ($zfin_reader->read_record) {
  my $record = $zfin_reader->record;
  push @records,$record;
}

my $expected_ids = ['ZDB-GENE-000112-47'];
is_deeply([map {$_->id} @records], $expected_ids, 'Records with a uniprot context extracted');

$expected_ids = [qw/O42545 A9C4A3 Q90Z66 A9C4A4 A9C4A5/];
is_deeply([map { $_->id } @{ $records[0]->xref }], $expected_ids, 'Uniprot xrefs all present for first record');

### And the same again for refseq file

$source = $ENV{MONGOOSE}."/t/data/refseq.txt";
$zfin_reader = new Bio::EnsEMBL::Mongoose::Parser::ZFIN(
    source_file => $source,
);

@records = ();
while ($zfin_reader->read_record) {
  my $record = $zfin_reader->record;
  push @records,$record;
}

$expected_ids = [qw/XM_009303928 NP_571543 XM_009303927 XP_009302203 NM_131468/];
is_deeply([map { $_->id } @{ $records[0]->xref } ], $expected_ids, 'Refseq xrefs also extracted');

done_testing;
