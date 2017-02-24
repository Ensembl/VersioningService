use Test::More;
use Test::Differences;
use strict;
use FindBin qw/$Bin/;
use lib "$Bin";
use Bio::EnsEMBL::Mongoose::Utils::ExonerateAligner;
# Not testing the actual binary, just the in and output.

my $exonerate = Bio::EnsEMBL::Mongoose::Utils::ExonerateAligner->new(source => 'test', target => 'pruefen');
$exonerate->set_method('best_90%');
my $command = $exonerate->build_command;

is($command, 'exonerate --showalignment false --showvulgar false --ryo xref\t%qi\t%ti\t%ei\t%ql\t%tl\t%qab\t%qae\t%tab\t%tae\t%C\t%s\n '
  .'--gappedextension false --model affine:local --bestn 1 --subopt no --query test --target pruefen ', 'Sanity check on parameters for exonerate');

my $spurious_exonerate_output = "xref\tENST01\tNM003\t99.2\t100\t110\t1\t100\t1\t100\tM\t110\n";
my $hits = $exonerate->output_filter($spurious_exonerate_output);

my $match = $hits->{'ENST01:NM003'};
is_deeply($match, {score => 110, query_identity => '0.99', target_identity => '0.90'}, 'See that identities are computed correctly');


$spurious_exonerate_output = "xref\tENST01\tNM003\t55\t100\t1100\t1\t100\t1\t100\tM\t110\n";
$hits = $exonerate->output_filter($spurious_exonerate_output);
cmp_ok(scalar keys %$hits, '==', 0, 'No hits from dissimilar input');

# Test chunking behaviour

for (my $i = 1; $i<=3; $i++) {
  $exonerate = Bio::EnsEMBL::Mongoose::Utils::ExonerateAligner->new(source => 'test', target => 'pruefen',chunk_cardinality => 3, execute_on_chunk => $i);
  $exonerate->set_method('best_90%');
  $command = $exonerate->build_command;
  is($command, 'exonerate --showalignment false --showvulgar false --ryo \'xref\t%qi\t%ti\t%ei\t%ql\t%tl\t%qab\t%qae\t%tab\t%tae\t%C\t%s\n\' '
  ."--gappedextension false --model affine:local --bestn 1 --subopt no --query test --target pruefen --querychunktotal 3 --querychunkid $i", 'Chunking parameters for exonerate');

}


done_testing;