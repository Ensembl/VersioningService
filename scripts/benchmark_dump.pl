use strict;
use warnings;

use FindBin qw/$Bin/;
use Log::Log4perl;
Log::Log4perl::init("$Bin/../conf/logger.conf");

use Bio::EnsEMBL::Mongoose::Mfetcher;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use IO::File;

my $fh = IO::File->new('dirty_great_file.fa','w');

my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    #evidence_level => 1,
    taxons => [40674],
);

my $mfetcher = Bio::EnsEMBL::Mongoose::Mfetcher->new(
    storage_engine_conf => "$Bin/../conf/swissprot.conf",
    query_params => $params,
    handle => $fh,
);

$mfetcher->get_sequence_including_descendants;
