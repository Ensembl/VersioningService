
# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::Versioning::Broker;

use Moose;

use FindBin qw/$Bin/;
use Log::Log4perl;
use Config::General;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;
use Data::Dumper;

use Bio::EnsEMBL::Versioning::Manager;
use Bio::EnsEMBL::Versioning::Manager::Source;
use Bio::EnsEMBL::Mongoose::DBException;
use Bio::EnsEMBL::Mongoose::UsageException;

my $conf = Config::General->new("$Bin/../conf/manager.conf");
my %opts = $conf->getall();

# supply a temp folder for downloading to.
sub temp_location {
    my $self = shift;
    my $root = $opts{temp};
    my $dir = tempdir(DIR => $root, CLEANUP => 1);
    $self->temp_file_path($dir);
}


# generate a storage folder derived from the type and version of a source
sub location {
    my $self = shift;
    my $source = shift;
    
    my $root = $opts{home};
    my $path = $root.'/'.$source->source_group->name.'/'.$source->name().'/'.$source->version->revision();
    make_path($path, { mode => '774'});
    return $path;
}

sub get_current_source_by_name {
    my $self = shift;
    my $source_name = shift;
    unless ($source_name) {Bio::EnsEMBL::Mongoose::UsageException->throw('Cannot get a source without a source name')};
    my $sources = Bio::EnsEMBL::Versioning::Manager::Source->get_sources(
        require_objects => ['current_version'], 
        query => [ name => $source_name ],
        debug => 1,
    );
    if (scalar(@$sources) == 0) { Bio::EnsEMBL::Mongoose::DBException->throw('No source found for '.$source_name.'. Possible integrity issue')};
    return $sources->[0];
}

sub list_versions_by_source {
    my $self = shift;
    my $source_name = shift;
    unless ($source_name) {Bio::EnsEMBL::Mongoose::UsageException->throw('Versions of a source demand an actual source')};
    my $versions = Bio::EnsEMBL::Versioning::Manager::Source->get_sources(
        query => [ name => $source_name ], 
        require_objects => ['version'], 
        sort_by => 'version.revision',
    );
    if (scalar(@$versions) == 0) { Bio::EnsEMBL::Mongoose::DBException->throw('No versions found for source: '.$source_name.'. Possible integrity issue')};
    my $revisions = [ map {$_->revision} @{$versions->[0]->version} ];
    return $revisions;
}

sub get_source_by_name_and_version {
    my $self = shift;
    my $source_name = shift;
    my $version = shift;
    unless ($source_name && $version) {Bio::EnsEMBL::Mongoose::UsageException->throw('Cannot get a source without a source name AND version number')};
    my $sources = Bio::EnsEMBL::Versioning::Manager::Source->get_sources(
        query => [ name => $source_name, 'version.revision' => $version],
        require_objects => ['version'],
    );
    if (scalar(@$sources) == 0) { Bio::EnsEMBL::Mongoose::DBException->throw('No source: '.$source_name.' found with version '.$version)}
    return $sources->[0];
}

1;