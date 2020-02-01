# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
use warnings;

use Modern::Perl;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Try::Tiny;
use RDF::Trine;
use RDF::Trine::Serializer::NTriples;
use Data::Dumper;
use IO::File;

Bio::EnsEMBL::Registry->load_registry_from_db(
  -HOST => 'mysql-ensembl-mirror.ebi.ac.uk',
  -PORT => 4240,
  -DB_VERSION => 76,
  -USER => 'anonymous',
);
# my $tstore = RDF::Trine::Store::Memory->new();
my $model = RDF::Trine::Model->temporary_model;
my $serializer = RDF::Trine::Serializer::NTriples->new();
my $ens = RDF::Trine::Namespace->new('http://www.ensembl.org/');
my $entity_ns = "http://purl.ensembl.org/";

my $ga = Bio::EnsEMBL::Registry->get_adaptor('panda','core','gene');

my $sql_helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $ga->dbc);

my %sql = (gene => 'SELECT x.dbprimary_acc, g.stable_id, x.info_type FROM xref x, object_xref o, gene g WHERE o.xref_id = x.xref_id AND o.`ensembl_id` = g.gene_id LIMIT 500',
           transcript => 'SELECT x.dbprimary_acc, t.stable_id, x.info_type FROM xref x, object_xref o, transcript t WHERE o.xref_id = x.xref_id AND o.`ensembl_id` = t.transcript_id;',
           translation => 'SELECT x.dbprimary_acc, t.stable_id, x.info_type FROM xref x, object_xref o, translation t WHERE o.xref_id = x.xref_id AND o.`ensembl_id` = t.translation_id;'
          );
my $counter = 0;
my $fh = IO::File->new("> triples_$counter");;

foreach (qw(gene transcript translation)) {
  my $iterator = $sql_helper->execute(-SQL => $sql{$_}, -ITERATOR => 1);
  my $hash_map = {};
  while ($iterator->has_next) {
    my ($external_id,$stable_id,$info_type) = @{ $iterator->next };
    $counter++;
    say $counter if $counter % 100 == 0;
    $hash_map->{ $entity_ns.$external_id } = { $entity_ns.'references' => [ { type => 'uri', value => $entity_ns.$stable_id } ] };
    if ( $counter % 10000 == 0) {
      # print Dumper $hash_map;
      $model->add_hashref($hash_map); 
      $serializer->serialize_model_to_file($fh, $model);
      $fh->close;
      say "Opening triples_$counter";
      $fh = $fh = IO::File->new("> triples_$counter");
    }
  }
}
