use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Deep;
use Log::Log4perl;

BEGIN {
  use FindBin qw/$Bin/;
  $ENV{MONGOOSE} = "$Bin/..";
  $ENV{LOG} = "$Bin";
}

my $log_file = $ENV{LOG} . "/mirbase.t.log";
my $log_conf = <<"LOGCONF";
log4perl.logger=DEBUG, Screen, File

log4perl.appender.Screen=Log::Dispatch::Screen
log4perl.appender.Screen.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern=%d %p> %F{1}:%L - %m%n

log4perl.appender.File=Log::Dispatch::File
log4perl.appender.File.filename=$log_file
log4perl.appender.File.mode=append
log4perl.appender.File.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.File.layout.ConversionPattern=%d %p> %F{1}:%L - %m%n
LOGCONF

Log::Log4perl::init(\$log_conf);

note 'Temporary tests to check whether the ensembl-io EMBL parser can be used';
use Data::Dumper;
use Bio::EnsEMBL::IO::Parser::EMBL;

open my $fh, "<:gzip(autopop)", "$ENV{MONGOOSE}/t/data/miRNA.dat.gz" or die "Cannot open file: $!\n";
my $parser = Bio::EnsEMBL::IO::Parser::EMBL->open($fh);

# check first record
$parser->next;
cmp_deeply($parser->get_accessions(), ['MI0000001'], 'First record accession');
is($parser->get_id(), 'cel-let-7', 'First record ID');
my $species = join(' ', (split /\s/, $parser->get_description())[0,1]);
is($species, 'Caenorhabditis elegans', 'First record species');
is($parser->get_sequence(), 'uacacuguggauccggugagguaguagguuguauaguuuggaauauuaccaccggugaacuaugcaauuuucuaccuuaccggagacagaacucuucga', 'First record sequence');

# seek inside the file
$parser->next for 1 .. 60;
cmp_deeply($parser->get_accessions(), ['MI0000063'], 'Record accession');
is($parser->get_id(), 'hsa-let-7b', 'Record ID');
$species = join(' ', (split /\s/, $parser->get_description())[0,1]);
is($species, 'Homo sapiens', 'Record species');
is($parser->get_sequence(), 'cggggugagguaguagguugugugguuucagggcagugauguugccccucggaagauaacuauacaaccuacugccuucccug', 'Record sequence');

$parser->close;

unlink $log_file;

done_testing();
