use Modern::Perl;

use MongooseHelper;
use IO::File;
use Log::Log4perl;
use Bio::EnsEMBL::Mongoose::IndexSearch;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;

my $opts = MongooseHelper->new_with_options();

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $neat_species = $opts->species;
$neat_species =~ s/\s+/_/g;
my $fh = IO::File->new(sprintf "%s/%s_triples.ttl",$opts->dump_path,$neat_species,'w');

my $extractor = Bio::EnsEMBL::Mongoose::IndexSearch->new(
  handle => $fh, 
  species => $opts->species, 
  output_format => 'RDF', 
  storage_engine_conf_file => $ENV{MONGOOSE}.'/conf/manager.conf'
);


my @source_list = @{ $opts->source_list }; #qw/Swissprot MIM mim2gene HGNC/;
for my $source (@source_list) {
  $extractor->work_with_index(source =>$source);
  $extractor->get_records;
}