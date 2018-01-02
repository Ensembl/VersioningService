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
use Algorithm::Diff;
use URI::Escape 'uri_unescape';
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
while( my $transcript = shift @$transcripts) {
  my $id = $transcript->stable_id;
  next if $seen{$id};
  my $id_list;
  my @pruned_list;
  try {
    my $before = [gettimeofday];
    $id_list = $sparqler->recurse_mini_graph($id);
    $time = tv_interval($before, [gettimeofday]);
  } catch {
    # print "$id not found\n";      
  };
  if ($id_list) {
    # printf "%s: %s hits in %s seconds: %s\n",$id,scalar @$id_list, $time, join(',',@$id_list);
    # cache Ensembl IDs from results
    foreach my $uri (@$id_list) {
      my ($ens_id) = $uri =~ /^<http:\/\/rdf.ebi.ac.uk\/resource\/ensembl\/(.+)>/;
      if ($ens_id) {
        $seen{$ens_id} = 1 if $ens_id;
      } else {
        my ($other_id) = $uri =~ /([^\/]+)(?=>$)/;
        $other_id = uri_unescape($other_id);
        push @pruned_list, $other_id if $other_id;
      }
    }
  }
  compare_with_ensembl($transcript,\@pruned_list);
  # last;
}

sub compare_with_ensembl {
  my $transcript = shift;
  my $id_list = shift;

  # load classic xrefs:
  my @old_xrefs = sort map { $_->primary_id } @{ $transcript->get_all_DBLinks() };
  my $diff = Algorithm::Diff->new([sort @$id_list], \@old_xrefs);
  my $similarities = 0;
  my (@old,@new);
  while ($diff->Next()) {
    if ($diff->Same()) {
      $similarities++;
      next;
    } else {
      push @new, $diff->Items(1);
      push @old, $diff->Items(2);
    }
  }
  
  printf "%s\t%s\t%s\t%s\t%s\t%s\n", $transcript->stable_id, $similarities, scalar @old, scalar @new, join(',',@old), join(',',@new);
  
}
