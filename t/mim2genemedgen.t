use Test::More;
use Test::Differences;

use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");
use Data::Dumper;
use Bio::EnsEMBL::Mongoose::Parser::MIM2GeneMedGen;

my $reader = Bio::EnsEMBL::Mongoose::Parser::MIM2GeneMedGen->new(
    source_file => "$ENV{MONGOOSE}/t/data/mim2gene_medshort",
);


note "Unique records in file: ".$reader->has_records;
my @ids;
my $record_of_interest;
while (my $record = $reader->read_record) {
  push @ids,$record->id;
  if ($record->id eq 100100) {
    $record_of_interest = $record;
  }
  # print Dumper $record;
}

is_deeply(\@ids, [qw/100050 100070 100100 100200 100300 100600 100640 100650 100660/], 'IDs extracted from file match');

my @xrefs = @{$record_of_interest->xref};
is ($record_of_interest->id,'100100','Check correct record extracted');

# print Dumper $record_of_interest;
cmp_ok(scalar @xrefs,'==',2,'Two xrefs on MIM 100100');



done_testing;