use Modern::Perl;
use Test::More;
use FindBin qw/$Bin/;

use Bio::EnsEMBL::Mongoose::AlignmentMethodFactory;

my $method_factory = Bio::EnsEMBL::Mongoose::AlignmentMethodFactory->new();

ok($method_factory->are_you_there('uniprot'),'Default accessors');

is($method_factory->get_method_by_species_and_source('gopher','holes'),'top5_90%','default method'); 
is($method_factory->get_method_by_species_and_source('human','UniProt'),'top5_90%','Uniprot specific method'); 
is($method_factory->get_method_by_species_and_source('human','UNIProt'),'top5_90%','Capitalisation irrelevant');
is($method_factory->get_method_by_species_and_source('human','refseq'),'top5_90%','RefSeq general case');
is($method_factory->get_method_by_species_and_source('saccharomyces_cerevisiae','refseq'),'best_exact','RefSeq special case');

done_testing();