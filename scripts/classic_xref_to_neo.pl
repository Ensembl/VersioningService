# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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
use REST::Neo4p;
use Try::Tiny;

Bio::EnsEMBL::Registry->load_registry_from_db(
  -HOST => 'mysql-ensembl-mirror.ebi.ac.uk',
  -PORT => 4240,
  -DB_VERSION => 76,
  -USER => 'anonymous',
);

my $ga = Bio::EnsEMBL::Registry->get_adaptor('panda','core','gene');

REST::Neo4p->connect('http://127.0.0.1:7474');

my $sql_helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $ga->dbc);

my %sql = (gene => 'SELECT x.dbprimary_acc, g.stable_id, x.info_type FROM xref x, object_xref o, gene g WHERE o.xref_id = x.xref_id AND o.`ensembl_id` = g.gene_id LIMIT 500'
          # transcript => 'SELECT x.dbprimary_acc, t.stable_id, x.info_type FROM xref x, object_xref o, transcript t WHERE o.xref_id = x.xref_id AND o.`ensembl_id` = t.transcript_id;',
          # translation => 'SELECT x.dbprimary_acc, t.stable_id, x.info_type FROM xref x, object_xref o, translation t WHERE o.xref_id = x.xref_id AND o.`ensembl_id` = t.translation_id;'
          );

foreach (qw(gene transcript translation)) {
  my $iterator = $sql_helper->execute(-SQL => $sql{$_}, -ITERATOR => 1);

  say 'Querying Ensembl: '.$sql{$_};
  my @errors = batch {
    while (my ($external_id,$stable_id,$info_type) = @{ $iterator->next }) {
      print '.';
      my $n1 = REST::Neo4p::Node->new({ id => $stable_id});
      $n1->set_property({version => 75});
      my $n2 = REST::Neo4p::Node->new({ id => $external_id});
      $n2->set_property({version => '2014_04'});
      my $relation;
      given ($info_type) {
        when ('COORDINATE_OVERLAP') {$relation = 'still_here'}
        when ('PROJECTION') {$relation = 'references'}
        when ('SEQUENCE_MATCH') {$relation = 'aligns'}
        when ('CHECKSUM') {$relation = 'identical_to'}
        default { $relation = 'references'}
      };
      my $r1 = $n2->relate_to($n1, $relation);

    }
  } 'discard_objs';
  my $e = Exception::Class->caught('REST::Neo4p::Exception');
  say;
  if ($e) {
    die "Ooer, ".$e;
  }
}

