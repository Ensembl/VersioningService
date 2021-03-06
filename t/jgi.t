use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Deep;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Parser::JGI';

my $reader =
  Bio::EnsEMBL::Mongoose::Parser::JGI->new(source_file => "$ENV{MONGOOSE}/t/data/ciona.prot.fasta.gz");
isa_ok($reader, 'Bio::EnsEMBL::Mongoose::Parser::JGI');

my $num_records = 0;

# check first record
$reader->read_record and ++$num_records;
my $record = $reader->record;
is($record->accessions->[0], 'ci0100130000', 'First record accession');
is($record->display_label, 'ci0100130000', 'First record display label');
is($record->taxon_id, 7719, 'First record tax id');
my $sequence = join '',
  qw /
       MPLEENISSSKRKPGSRGGVSFFSYFTQELTHGYFMDQNDARYTERRERVYTFLKQPREIEKVRPFPPFL
       CLDVFLYVFTFLPLRVLFALLKLLSAPFCWFQRRSLLDPAQSCDLLKGVIFTSCVFCMSYIDTSIIYHLV
       RAQTLIKLYIIYNMLEVADRLFSSFGQDILDALFLTATESNRQKRESFRVLLHLILAVIYVFSHAVLVLF
       EATTLNVAFNSHNKVLLTIMMANNFVEIKGTVFKKYDKNNLFQISCSDIRERFHYFALMLVVLLRNMQQY
       SWNYEHFTEIIPNMLMLLSSECVVDWFKHAFVLKFNHIPIESYSEYRATLAYDVASSRHKDSINDHSDVV
       SRRLGFIPLPLAVLVSYSSALLLPVSDFSVCSSVLVYRIKKRFV*MHFSSLTLLKVFNSIVIVGKACCYI
       SDDEAQAANVRVNGARIAVVDPFEQRGNKTILVSQARAQPPEPTVKPPASGDPGLDSKKLLLSPEKNRKL
       PKEVTTPARLRSMRAPSVDHTVAAGTNLPSRNDDDVGDVDVLRHQAPDSVRSRKRHTATIVKATAIDEEI
       H*
     /;
is($record->sequence, $sequence, 'First record sequence');

# seek inside the file
$reader->read_record() and ++$num_records for 1 .. 499;
$record = $reader->record;
is($record->accessions->[0], 'ci0100130502', 'Correct record ID');
is($record->display_label, 'ci0100130502', 'Correct record display label');
is($record->taxon_id, 7719, 'Correct record tax id');
$sequence = join '',
  qw /
       MLSDIKKNKGQLVEREQLVTEAKKSAKLFGDHPQPQLTLDAFLETVGQLKFRGTSGLYRMHEKPWMVNLK
       RGRESPGWGIPRGESSTETKTNFGQRSNIKFDSNGCNYGKIIKAVCLRIKRKINNQCHPDINIPQTPPHD
       TLNEVDEPYTLALHSVKVRRTGTTVEAKSLWELGVSDSVPVVGDVTSMAF*MDSSHFNNINLIINPKLYL
       RLLKLQAPTYILGDIHGNHHDLVCFEKSLWRVGPLLTPCRFLFLGDYVDRGENGVEVVAYLLSQKILCPN
       KIFMVRGNHELRDIQVAFSFQTECVRKFGENLGIKVWEQINSCFDMLPIAAVVDNKIFTAHGGIPNSDTY
       ASYNNVVEAINNIPTPLSNPEVESPLAWELMWNDPIRLASVKLLSEGFVHNHRRKTASMFTSAALEKFLA
       SNKFTHVIRAHEVQQIGFKVG*
     /;
is($record->sequence, $sequence, 'Correct record sequence');

# read all the records until the end of the file
while ($reader->read_record()) {
  $record = $reader->record;
  ++$num_records;
}
ok(1, 'Reached end of file without dying');
is($num_records, 1000, "Successfully read all $num_records records from file");

done_testing();
