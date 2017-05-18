use strict;
use Test::More;
use Test::Differences;
use Test::Exception;
use IO::String;

use FindBin qw/$Bin/;
use lib "$Bin";
use TestDefaults;

use Bio::EnsEMBL::Mongoose::IndexSearch;
use Bio::EnsEMBL::Mongoose::Persistence::QueryParameters;

my $params = Bio::EnsEMBL::Mongoose::Persistence::QueryParameters->new(
    taxons => [9606],
);

my $content;
my $io = IO::String->new($content);

my $reader = Bio::EnsEMBL::Mongoose::IndexSearch->new(
    storage_engine_conf_file => "$Bin/../conf/test.conf",
    query_params => $params,
    handle => $io,
    output_format => 'ID'
);

# Crudely test the custom filter support on output
$reader->filter(sub { my $record = shift; return 1 if $record->primary_accession eq 'P15056'});
$reader->get_records;
is ($content,"P15056\n" ,'Check that only one uniprot record has been dumped');

$io->setpos(0);
$reader->disable_filter;
$reader->get_records;

is ($content,"P15056\n" ,'Index only has one record, and here it is');


$content = '';
$io->setpos(0);
$reader->filter(sub { return 0});
$reader->get_records;
is($content, '', 'No output, because it has all been filtered');

# Testing sparse due to difficulty in meaningfully testing other methods.


done_testing;