use Test::More;
use Test::Differences;

use FindBin qw/$Bin/;

use Bio::EnsEMBL::Mongoose::Taxonomizer;

my $taxi = Bio::EnsEMBL::Mongoose::Taxonomizer->new;
my $list = $taxi->fetch_nested_taxons(9606);

note("Nested taxons: ".join(',',@$list)."\n");

# Test only applies until someone adds a new human subbranch.
is_deeply($list,[9606,741158,63221],'Test Human taxon relatives');


done_testing;