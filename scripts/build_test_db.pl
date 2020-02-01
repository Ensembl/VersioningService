# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Script to build the test database used by the test suite. Run after major updates to document structure or content

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../t";
use TestDefaults;

use Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster;
use Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder;

my $index_location = "$Bin/../t/data/test.index";
my $data_location = "$Bin/../t/data/braf.xml";

my $parser = Bio::EnsEMBL::Mongoose::Parser::SwissprotFaster->new( source_file => $data_location );
my $doc_store = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new( index => $index_location);

my $buffer = 0;
while ($parser->read_record) {
  my $record = $parser->record;
  $doc_store->store_record($record);
  $buffer++;
  if ($buffer % 1000 == 0) {
    $doc_store->commit;
    $doc_store = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new( index => $index_location);
  }
}

$doc_store->commit;
print "Test DB created at \$MONGOOSE/t/data/test.index\n";
