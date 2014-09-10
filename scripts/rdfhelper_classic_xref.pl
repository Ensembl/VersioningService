use strict;
use warnings;

use Modern::Perl;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::SqlHelper;
use Try::Tiny;
use Data::Dumper;
use IO::File;
use RDF::Helper;


Bio::EnsEMBL::Registry->load_registry_from_db(
  -HOST => 'mysql-ensembl-mirror.ebi.ac.uk',
  -PORT => 4240,
  -DB_VERSION => 76,
  -USER => 'anonymous',
  -RECONNECT_WHEN_LOST => 1,
);
my $ga = Bio::EnsEMBL::Registry->get_adaptor('panda','core','gene');
my $sql_helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $ga->dbc);

my $helper = RDF::Helper->new(
  BaseInterface => 'RDF::Trine',
  namespaces => {
    dct => 'http://purl.org/dc/terms/',
    rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    ens => 'http://purl.ensembl.org/',
    upi => 'http://purl.uniprot.org/',
    refseq => 'http://purl.refseq.org/',
    go => 'http://geneontology.org/',
    other => 'http://whatever.org/',
  },
  ExpandQNames => 1
);


my %sql = (gene => 'SELECT x.dbprimary_acc, g.stable_id, x.info_type FROM xref x, object_xref o, gene g WHERE o.xref_id = x.xref_id AND o.`ensembl_id` = g.gene_id',
           transcript => 'SELECT x.dbprimary_acc, t.stable_id, x.info_type FROM xref x, object_xref o, transcript t WHERE o.xref_id = x.xref_id AND o.`ensembl_id` = t.transcript_id;',
           translation => 'SELECT x.dbprimary_acc, t.stable_id, x.info_type FROM xref x, object_xref o, translation t WHERE o.xref_id = x.xref_id AND o.`ensembl_id` = t.translation_id;'
          );
my $counter = 0;
my $fh = IO::File->new(">panda_triples_0");
foreach (qw(gene transcript translation)) {
  my $iterator = $sql_helper->execute(-SQL => $sql{$_}, -ITERATOR => 1);
  while ($iterator->has_next) {
    my ($external_id,$stable_id,$info_type) = @{ $iterator->next };
    $counter++;
    say $counter if $counter % 100 == 0;
    if ($external_id =~ /^UP/) {
      $helper->assert_resource("upi:$external_id","ens:refers-to","ens:$stable_id");
    } elsif ($external_id =~ /^N[MP]/) {
      $helper->assert_resource("refseq:$external_id","ens:refers-to","ens:$stable_id");
    }
    elsif ($external_id =~ /^GO/) {
      $helper->assert_resource("go:$external_id","ens:refers-to","ens:$stable_id");
    } else {
      $helper->assert_resource("other:$external_id","ens:refers-to","ens:$stable_id");
    }
    if ( $counter % 10000 == 0) {
      $helper->serialize(format => 'ntriples', filename => $fh);
      $fh->close;
      $fh = IO::File->new(">panda_triples_$counter");
      $helper = RDF::Helper->new(
        BaseInterface => 'RDF::Trine',
        namespaces => {
          dct => 'http://purl.org/dc/terms/',
          rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
          ens => 'http://purl.ensembl.org/',
          upi => 'http://purl.uniprot.org/',
          refseq => 'http://purl.refseq.org/',
          other => 'http://whatever.org/',
        },
        ExpandQNames => 1
        );
    }
  }
}
