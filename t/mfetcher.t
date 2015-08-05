use Test::More;
use Test::Differences;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
use FindBin qw/$Bin/;
use Bio::EnsEMBL::Mongoose::IndexSearch;
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

my $mfetcher = Bio::EnsEMBL::Mongoose::IndexSearch->new(
    storage_engine_conf_file => "$Bin/../conf/test.conf",
    query_params => $params,
    handle => $fh,
);

$mfetcher->get_records;

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
# $params->species_name('Hylarana picturata');
$params->species_name('Pulchrana picturata');

$mfetcher->convert_name_to_taxon;
is($params->taxons->[0],395594,'Test name conversion');

$params->clear_species_name;
$params->taxons([8397]); # riparian frogs in NCBI taxonomy (as of Compara 81)
$mfetcher->get_records_including_descendants;

$desired = "> P0C8T7 395594 1 
GFLDSFKNAMIGVAKSVGKTALSTLACKIDKSC
> P84858 110109 1 
FLPLLFGAISHLL
";
is($out,$desired, 'Did taxon descendants return correct sequence combinations?');

# test blacklist
my $blacklist_file = 'data/blacklist.txt';
$mfetcher->blacklist_source($blacklist_file);
$mfetcher->get_records;

# Build a new Mfetcher to use a different output format
undef($mfetcher);
$out = '';
$fh = IO::String->new($out);
$fh->setpos(0);
$params->taxons([110109]);
$params->evidence_level('1');
$mfetcher = Bio::EnsEMBL::Mongoose::IndexSearch->new(
    storage_engine_conf_file => "$Bin/../conf/test.conf",
    query_params => $params,
    handle => $fh,
    output_format => 'JSON',
);

$mfetcher->get_records;
is($out,'{"evidence_level":1,"xref":[{"source":"GO","creator":"UniProtKB-SubCell","active":1,"id":"GO:0005576"},{"source":"GO","creator":"UniProtKB-SubCell","active":1,"id":"GO:0042742"}],"sequence":"FLPLLFGAISHLL","taxon_id":"110109","sequence_length":13,"protein_name":"Temporin-GH","entry_name":"TEMP_RANGU","accessions":["P84858"],"sequence_version":"1"}');
done_testing;