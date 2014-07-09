use strict;
use warnings;

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::Serializer::FASTA;
use Bio::EnsEMBL::Mongoose::Mfetcher;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use Data::Dump::Color qw/dump/;
use Log::Log4perl;

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $query = shift;
die "Specify query string" unless $query;

my $mfetcher = Bio::EnsEMBL::Mongoose::Mfetcher->new();
$mfetcher->work_with_source('UniProtSwissProt','2014_04');

my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    species_name => $query
    # ids => ['Q13878'],
    # id_type => 'accessions',
    # evidence_level => 1,
    # taxons => [9606],
);
$mfetcher->query_params($params);

$mfetcher->get_records_by_species_name();

