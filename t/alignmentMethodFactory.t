use Modern::Perl;
use Test::More;
use FindBin qw/$Bin/;

use Bio::EnsEMBL::Mongoose::Utils::AlignmentMethodFactory;

my $method_factory = Bio::EnsEMBL::Mongoose::Utils::AlignmentMethodFactory->new();

ok($method_factory->are_you_there('uniprot'),'Default accessors');

is($method_factory->get_method_by_species_and_source('gopher','holes'),'top5_90%','default method'); 
is($method_factory->get_method_by_species_and_source('human','UniProt'),'best_exact','Uniprot specific method'); 
is($method_factory->get_method_by_species_and_source('human','UNIProt'),'best_exact','Capitalisation irrelevant');
is($method_factory->get_method_by_species_and_source('human','refseq'),'top5_90%','RefSeq general case');
is($method_factory->get_method_by_species_and_source('saccharomyces_cerevisiae','refseq'),'best_exact','RefSeq special case');

is($method_factory->get_method_by_species_and_source('rattus_norvegicus','RefSeq'),'top5_90%','Trouble with RefSeq source name?');

is($method_factory->get_method_by_species_and_source('rattus_norvegicus','RefSeq','pep'),'top5_20%' ,'Special redirect for RefSeq protein matching works');
is($method_factory->get_method_by_species_and_source('rattus_norvegicus','RefSeq','cdna'),'top5_90%' ,'Special redirect for RefSeq does not affect non-peptide data');

done_testing();