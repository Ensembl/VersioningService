# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Trial script to process TTL files into derived xrefs and happy results


use Modern::Perl;
use File::Spec;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Time::HiRes qw/gettimeofday tv_interval/;
use Bio::EnsEMBL::RDF::XrefReasoner;
use Bio::EnsEMBL::Registry;
use File::Slurper 'read_dir';
use IO::File;
use XrefScriptHelper;


my $opts = XrefScriptHelper->new_with_options();

my $debug_fh;
if ($opts->debug == 1) {
  printf "Debug is turned ON and going to %s\n",$opts->debug_file;
  $debug_fh = IO::File->new($opts->debug_file ,'w') || die "Unable to create debug output:".$opts->debug_file;
}

my $reasoner = Bio::EnsEMBL::RDF::XrefReasoner->new(keepalive => 0, memory => $opts->fuseki_heap, debug_fh => $debug_fh);

# PHASE 1, process the coordinate overlaps into default model

my $data_root = File::Spec->catfile($opts->ttl_path,$opts->species,'xref_rdf_dumps');
my $overlap_source = File::Spec->catfile($data_root,'coordinate_overlap','refseq_coordinate_overlap.ttl');
my $e_gene_model = File::Spec->catfile($data_root,'gene_model','ensembl.ttl');
my $refseq_gene_model = File::Spec->catfile($data_root,'gene_model','RefSeq.ttl');
my $checksum_source = File::Spec->catfile($data_root,'checksum','RefSeq_checksum.ttl');
my $alignment_source = File::Spec->catfile($data_root,'alignment');

# Get all TTL files in data_root not in a subdirectory
my @loadables = read_dir($data_root);
@loadables = map { $data_root.'/'.$_ } grep { /.ttl/ } @loadables;
my $transitive_data = File::Spec->catfile($data_root,'transitive');
my @transitive = read_dir($transitive_data);
@transitive = map { $transitive_data.'/'.$_} @transitive;

my $start_time = [gettimeofday];
$reasoner->load_general_data($overlap_source,$e_gene_model,$refseq_gene_model,$checksum_source,@loadables);
$reasoner->load_alignments($alignment_source);
$reasoner->load_transitive_data(\@transitive);
my $done_time = tv_interval($start_time,[gettimeofday]);
print "Alignments, checksums, overlaps and gene model loaded\n";
print "Loaded all data in $done_time seconds\n";

$reasoner->pretty_print_stats($reasoner->calculate_stats());
print "Stats finished, now select transitive xrefs into a new graph\n";
$reasoner->nominate_transitive_xrefs();
print "Transitive xrefs supplemented with choices from coordinate matches, alignments and such.\n";

my $ens_host = 'mysql-ensembl-mirror.ebi.ac.uk';
my $ens_port = 4240;
my $ens_user = 'anonymous';

my $matches_fh = IO::File->new($opts->output_file,'w');

# Consult Ensembl staging DB for this release' list of valid stable IDs
Bio::EnsEMBL::Registry->load_registry_from_db( -host => $ens_host, -port => $ens_port, -user => $ens_user, -db_version => 90);

foreach my $type (qw/gene transcript translation/) {
  my $adaptor = Bio::EnsEMBL::Registry->get_adaptor($opts->species,'core',$type);
  my $features = $adaptor->fetch_all();
  while (my $feature = shift $features) {
    # Get a list of all IDs that are "the same thing"
    my $identity_matches = $reasoner->extract_transitive_xrefs_for_id($feature->stable_id);
    if ($opts->debug == 1) {
      printf $matches_fh "%s\t%s\n",$feature->stable_id,join(',',@$identity_matches);
    }
  }
}

$matches_fh->close;
$debug_fh->close if $debug_fh;