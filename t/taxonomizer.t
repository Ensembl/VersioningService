use Test::More;
use Test::Differences;

use FindBin qw/$Bin/;

use Data::Dump::Color qw/dump/;
use Bio::EnsEMBL::Mongoose::Taxonomizer;

my $taxi = Bio::EnsEMBL::Mongoose::Taxonomizer->new;
my $list = $taxi->fetch_nested_taxons(9606);

note("Nested taxons: ".join(',',@$list)."\n");

# Test only applies until someone adds a new human subbranch.
is_deeply($list,[9606,741158,63221],'Test Human taxon relatives');

my $id = $taxi->fetch_taxon_id_by_name('eutheria');

cmp_ok($id,'==',9347,'Verify Compara is behaving');

done_testing;