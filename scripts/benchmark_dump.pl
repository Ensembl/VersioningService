use strict;
use warnings;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use Bio::EnsEMBL::Mongoose::IndexSearcher;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use IO::File;

my $fh = IO::File->new('dirty_great_file.fa','w');

my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    #evidence_level => 1,
    taxons => [40674],
);

my $mfetcher = Bio::EnsEMBL::Mongoose::IndexSearcher->new(
    storage_engine_conf => "$ENV{MONGOOSE}/conf/swissprot.conf",
    query_params => $params,
    handle => $fh,
);

$mfetcher->get_sequence_including_descendants;
