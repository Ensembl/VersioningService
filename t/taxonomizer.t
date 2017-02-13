use Test::More;
use Test::Differences;
use Test::Deep;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use_ok 'Bio::EnsEMBL::Mongoose::Taxonomizer';

SKIP: {
  skip "Cannot find configuration file required to instantiate Taxonomizer", 3
    unless -r "$ENV{MONGOOSE}/conf/databases.conf";

  my $tax = Bio::EnsEMBL::Mongoose::Taxonomizer->new();
  isa_ok($tax, 'Bio::EnsEMBL::Mongoose::Taxonomizer');

  my $id = $tax->fetch_taxon_id_by_name('eutheria');
  cmp_ok($id, '==', 9347, 'Fetch by taxon name');

  my $list = $tax->fetch_nested_taxons(9606);
  cmp_deeply($list, bag(9606, 63221, 741158), 'Test Human taxon relatives');

}

done_testing;
