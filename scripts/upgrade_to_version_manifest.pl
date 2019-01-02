# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

# Upgrade versioning schemas in situ
# perl upgrade_to_version_manifest.pl --host $host --port 3306 --user me -pass $pass  --db $host

# This script is specifically for populating data in the newly created table from schema version 1 to 2
# Pre-existing indexes are built in one go no matter how many files, so we only need to make one manifest entry
# This script has been run once. Think carefully before running it again.

use Modern::Perl;
use MongooseHelper;
use Bio::EnsEMBL::Versioning::Broker;
use Config::General;

# borrow config from the live setup wherein are specific DB connection parameters
my $conf = Config::General->new($ENV{MONGOOSE}.'/conf/manager.conf');
my $sql_dir = $ENV{MONGOOSE}.'/sql/';
my %opts = $conf->getall();
%opts = (%opts , %{ MongooseHelper->new_with_options() });

my $broker = Bio::EnsEMBL::Versioning::Broker->new(%opts);

my $sources = $broker->get_active_sources;

foreach my $source (@$sources) {
  my $version_names = $broker->list_versions_by_source($source->name);

  foreach my $version_name (@$version_names) {
    my $version = $broker->get_version_of_source($source->name,$version_name);
    
    print "\n".ref($version)."\n";
    # Now get the index path and create a "manifest" entry for it
    my $path = $version->index_uri;
    print $path."\n";
    $version->create_related('version_indexes',{ record_count => $version->record_count, index_uri => $path });
  }
}

say "Created manifest entries for all versions of sources currently present in DB";
