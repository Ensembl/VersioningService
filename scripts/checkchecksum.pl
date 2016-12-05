# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
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

# Demo script to test checksum comparisons against Uniprot sequences

use strict;
use warnings;

use Digest::MD5 qw(md5);

use Bio::EnsEMBL::Mongoose::Persistence::LucyQuery;
use Bio::EnsEMBL::Mongoose::IndexSearch;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use MongooseHelper;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
use Bio::EnsEMBL::Registry;
use IO::File;

my $opts = MongooseHelper->new_with_options();
my $base_path;
if (defined $opts->{dump_path}) {
  $base_path = $opts->{dump_path};
} else {
  $base_path = '.';
}
my $fh = IO::File->new($base_path.'/SwissprotIDs.txt','w');

my $ens_host = 'mysql-ensembl-mirror.ebi.ac.uk';
my $ens_port = 4240;
my $ens_user = 'anonymous';

Bio::EnsEMBL::Registry->load_registry_from_db( -host => $ens_host, -port => $ens_port, -user => $ens_user, -db_version => 86);

my $translation_adaptor = Bio::EnsEMBL::Registry->get_adaptor('human','core','translation');
my $trans_list = $translation_adaptor->fetch_all();

my $search = Bio::EnsEMBL::Mongoose::IndexSearch->new(
  handle => $fh,
  output_format => 'ID',
  storage_engine_conf_file => $ENV{MONGOOSE}.'/conf/manager.conf'
);
$search->work_with_index(source => 'Swissprot');

while (my $trans = shift @$trans_list) {
  my $id = $trans->stable_id;
  my $seq = $trans->seq;
  my $digest = md5($seq);
  $search->query_params(Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    taxons => [9606],
    checksum => $digest
  ));
  $search->get_records;
}

$fh->close;