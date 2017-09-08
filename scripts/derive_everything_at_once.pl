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
use File::Slurp;

my $species = shift;
my $ttl_path = shift;
die "Point to the ttl files location, not $ttl_path" unless $ttl_path and -e $ttl_path;

my $reasoner = Bio::EnsEMBL::RDF::XrefReasoner->new(keepalive => 1);

# PHASE 1, process the coordinate overlaps into default model

my $overlap_source = File::Spec->catfile($ttl_path,'xref_rdf_dumps','coordinate_overlap','refseq_coordinate_overlap.ttl');
# my $refseq_source = File::Spec->catfile($ttl_path,'xref_rdf_dumps','RefSeq.ttl');
my $e_gene_model = File::Spec->catfile($ttl_path,'xref_rdf_dumps','gene_model','ensembl.ttl');
my $refseq_gene_model = File::Spec->catfile($ttl_path,'xref_rdf_dumps','gene_model','RefSeq.ttl');
my $checksum_source = File::Spec->catfile($ttl_path,'xref_rdf_dumps','checksum','RefSeq_checksum.ttl');
my $alignment_source = File::Spec->catfile($ttl_path,'xref_rdf_dumps','alignment');

my @loadables = read_dir(File::Spec->catfile($ttl_path,'xref_rdf_dumps', prefix => 1));
@loadables = grep { /.ttl/ } @loadables;
my @transitive = read_dir(File::Spec->catfile($ttl_path,'xref_rdf_dumps','transitive', prefix => 1));

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
print "Transitive xrefs placed in new graph. Now compare with Ensembl\n";


my $ens_host = 'mysql-ensembl-mirror.ebi.ac.uk';
my $ens_port = 4240;
my $ens_user = 'anonymous';

my $matches_fh = IO::File->new('identity_matches.tsv','w');

# Consult Ensembl staging DB for this release' list of valid stable IDs
Bio::EnsEMBL::Registry->load_registry_from_db( -host => $ens_host, -port => $ens_port, -user => $ens_user, -db_version => 89);

foreach my $type (qw/gene transcript translation/) {
  my $adaptor = Bio::EnsEMBL::Registry->get_adaptor($species,'core',$type);
  my $features = $adaptor->fetch_all();
  while (my $feature = shift $features) {
    my $identity_matches = $reasoner->extract_transitive_xrefs_for_id($feature->stable_id);
    printf $matches_fh "%s\t%s\n",$feature->stable_id,join(',',@$identity_matches);
  }
}

$matches_fh->close;