# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

use strict;

use Modern::Perl;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Mongoose::Persistence::TriplestoreQuery;
use Try::Tiny;
use Time::HiRes qw(gettimeofday tv_interval);
my $ens_host = 'mysql-ensembl-mirror.ebi.ac.uk';
my $ens_port = 4240;
my $ens_user = 'anonymous';

Bio::EnsEMBL::Registry->load_registry_from_db( -host => $ens_host, -port => $ens_port, -user => $ens_user, -db_version => 87);

my $triplestore = 'http://127.0.0.1:8890/sparql';
my $sparqler = Bio::EnsEMBL::Mongoose::Persistence::TriplestoreQuery->new(triplestore_url => $triplestore, graph => 'http://minixrefs/');

my $transcript_adaptor = Bio::EnsEMBL::Registry->get_adaptor('human','core','transcript');
my $transcripts = $transcript_adaptor->fetch_all();
my %seen;
my $time;
foreach my $transcript (@$transcripts) {
  my $id = $transcript->stable_id;
  my $id_list;
  try {
    my $before = [gettimeofday];
    $id_list = $sparqler->recurse_mini_graph($id);
    $time = tv_interval($before, [gettimeofday]);
  } catch {
    print "$id not found\n";      
  };
  if ($id_list) {
    printf "%s: %s hits in %s seconds: %s\n",$id,scalar @$id_list, $time, join(',',@$id_list);
    # cache Ensembl IDs from results
    foreach my $uri (@$id_list) {
      my ($ens_id) = $uri =~ /^<http:\/\/rdf.ebi.ac.uk\/resource\/ensembl\/(ENS.+)>/;
      # print "Collecting $ens_id for caching\n" if $ens_id;
      $seen{$ens_id} = 1 if $ens_id;
    }
  }
  # last;
}
