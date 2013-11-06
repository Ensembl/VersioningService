use Test::More;
use Test::Differences;

use FindBin qw/$Bin/;
use Log::Log4perl;
Log::Log4perl::init("$Bin/../conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Mfetcher;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use IO::String;
my $out;
my $fh = IO::String->new($out);

my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    ids => ['Q13878'],
    id_type => 'accessions',
    evidence_level => 1,
    taxons => [9606],
);

my $mfetcher = Bio::EnsEMBL::Mongoose::Mfetcher->new(
    storage_engine_conf => "$Bin/../conf/test.conf",
    query_params => $params,
    handle => $fh,
);

$mfetcher->get_sequence;

# Beware \s at end of header line
my $desired = "> P15056 9606 1 
MAALSGGGGGGAEPGQALFNGDMEPEAGAGAGAAASSAADPAIPEEVWNIKQMIKLTQEH
IEALLDKFGGEHNPPSIYLEAYEEYTSKLDALQQREQQLLESLGNGTDFSVSSSASMDTV
TSSSSSSLSVLPSSLSVFQNPTDVARSNPKSPQKPIVRVFLPNKQRTVVPARCGVTVRDS
LKKALMMRGLIPECCAVYRIQDGEKKPIGWDTDISWLTGEELHVEVLENVPLTTHNFVRK
TFFTLAFCDFCRKLLFQGFRCQTCGYKFHQRCSTEVPLMCVNYDQLDLLFVSKFFEHHPI
PQEEASLAETALTSGSSPSAPASDSIGPQILTSPSPSKSIPIPQPFRPADEDHRNQFGQR
DRSSSAPNVHINTIEPVNIDDLIRDQGFRGDGGSTTGLSATPPASLPGSLTNVKALQKSP
GPQRERKSSSSSEDRNRMKTLGRRDSSDDWEIPDGQITVGQRIGSGSFGTVYKGKWHGDV
AVKMLNVTAPTPQQLQAFKNEVGVLRKTRHVNILLFMGYSTKPQLAIVTQWCEGSSLYHH
LHIIETKFEMIKLIDIARQTAQGMDYLHAKSIIHRDLKSNNIFLHEDLTVKIGDFGLATV
KSRWSGSHQFEQLSGSILWMAPEVIRMQDKNPYSFQSDVYAFGIVLYELMTGQLPYSNIN
NRDQIIFMVGRGYLSPDLSKVRSNCPKAMKRLMAECLKKKRDERPLFPQILASIELLARS
LPKIHRSASEPSLNRAGFQTEDFSLYACASPKTPIQAGGYGAFPVH
";
is($out,$desired, 'Check FASTA output');
$out = '';
$fh->setpos(0);
$params->ids([]);
$params->taxons([]);
$params->species_name('Hylarana picturata');


$mfetcher->convert_name_to_taxon;
is($params->taxons->[0],395594,'Test name conversion');

$params->clear_species_name;
$params->taxons([1008893]);
$mfetcher->get_sequence_including_descendants;

$desired = "> P0C8T7 395594 1 
GFLDSFKNAMIGVAKSVGKTALSTLACKIDKSC
> P84858 110109 1 
FLPLLFGAISHLL
";
is($out,$desired, 'Did taxon descendants return correct sequence combinations?');

# test blacklist
my $blacklist_file = 'data/blacklist.txt';
$mfetcher->blacklist_source($blacklist_file);
$mfetcher->get_sequence;

done_testing;