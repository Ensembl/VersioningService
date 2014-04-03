
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

use Env;
use Log::Log4perl;
use Config::General;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;
use File::Copy;
use File::Spec;
use IO::Dir;

use Try::Tiny;
use Class::Inspector;

use Bio::EnsEMBL::Versioning::Manager;
use Bio::EnsEMBL::Versioning::Manager::Source;
use Bio::EnsEMBL::Versioning::Object::Version;
use Bio::EnsEMBL::Mongoose::DBException;
use Bio::EnsEMBL::Mongoose::UsageException;
use Bio::EnsEMBL::Mongoose::IOException;

my $conf = Config::General->new($ENV{MONGOOSE}.'/conf/manager.conf');
my %opts = $conf->getall();

# subroutine to be called if using the broker outside of a pipeline or test suite.
sub init_broker {
  require Bio::EnsEMBL::Versioning::DB;
  Bio::EnsEMBL::Versioning::DB->register_db(
    domain   => 'ensembl',
    type     => 'default',
    driver   => $opts{driver},
    database => $opts{db},
    host     => $opts{host},
    username => $opts{user},
    password => $opts{pass},
    port     => $opts{port},
    server_time_zone => 'UTC',
  );
}

# supply a temp folder for downloading to.
sub temp_location {
    my $self = shift;
    my $root = $opts{temp};
    my $dir = tempdir(DIR => $root, CLEANUP => 1);
    return $dir;
}


# generate a storage folder derived from the type and version of a source
sub location {
    my $self = shift;
    my $source = shift;
    my $version = shift;

    my $root = $opts{home};
    my $path = $root.'/'.$source->source_group->name.'/'.$source->name().'/'.$version->revision();
    make_path($path, { mode => 0774 });
    return $path;
}

sub finalise_download {
    my $self = shift;
    my $source = shift;
    my $revision = shift;
    my $temp_location = shift;

    my $version = Bio::EnsEMBL::Versioning::Object::Version->new(revision => $revision);
    my $final_location = $self->location($source,$version);
    for my $file (glob $temp_location."/*") {
        move($file, $final_location.'/') || Bio::EnsEMBL::Mongoose::IOException->throw('Error moving files from temp space:'.$temp_location);
    }
    $version->uri($final_location);
    $source->version($version);
    $source->update;
    return $final_location;
}

sub get_current_source_by_name {
    my $self = shift;
    my $source_name = shift;
    unless ($source_name) {Bio::EnsEMBL::Mongoose::UsageException->throw('Cannot get a source without a source name')};
    my $sources = Bio::EnsEMBL::Versioning::Manager::Source->get_sources(
        require_objects => ['current_version'], 
        query => [ name => $source_name ],
    );
    # if (scalar(@$sources) == 0) { Bio::EnsEMBL::Mongoose::DBException->throw('No source found for '.$source_name.'. Possible integrity issue')};
    if (scalar(@$sources) == 0) {
      # No current version available. Starting from scratch.
      $sources = Bio::EnsEMBL::Versioning::Manager::Source->get_sources(
        query => [ name => $source_name ],
      );
    }
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

sub get_active_sources {
    my $self = shift;
    my $sources = Bio::EnsEMBL::Versioning::Manager::Source->get_sources(
        query =>[ active => 1 ],
    );
    return $sources;
}

sub get_file_list_for_source {
  my $self = shift;
  my $source = shift;
  my $dir = $source->version->[0]->uri;
  my @files = glob($dir.'/*');
  print "Found files: ".join(',',@files);
  return \@files;
}

sub document_store {
  my $self = shift;
  my $path = shift;
  my $doc_store_package = $opts{'doc_store'};
  unless ($doc_store_package) { Bio::EnsEMBL::Mongoose::UsageException->throw('Document store undefined in config. Specify doc_store = package::name ')}
  $self->get_module($doc_store_package);
  if ($path) {
    return $doc_store_package->new(index => $path);
  } else {
    return $doc_store_package->new(index => $self->temp_location);
  }
}

sub finalise_index {
  my $self = shift;
  my $source = shift;
  my $doc_store = shift;
  my $record_count = shift;

  my $temp_path = $doc_store->index;
  my $temp_location = IO::Dir->new($temp_path);
  my $final_location = $self->location($source,$source->version->[0]);
  print 'Moving index from '.$temp_path.' to '.$final_location."\n";
  while (my $file = $temp_location->read) {
    next if $file =~ /^\.+$/;
    move(File::Spec->catfile($temp_path,$file), File::Spec->catfile($final_location,'index',$file) )
      || Bio::EnsEMBL::Mongoose::IOException->throw('Error moving index files from temp space:'.$temp_location.'/'.$file.' to '.$final_location.'  '.$!);
  }
  $source->version->[0]->index_uri(File::Spec->catfile($final_location,'index'));
  $source->version->[0]->record_count($record_count);
  $source->version->[0]->update; # updates do not cascade from source
}

sub get_module {
  my $self = shift;
  my $name = shift;

  try {
    (my $file = $name) =~ s|::|/|g;
    if (!(Class::Inspector->loaded($name))) {
      require $file . '.pm';
      $name->import();
    }
    return $name;
  } catch {
    Bio::EnsEMBL::Mongoose::UsageException->throw("Module $name could not be found. $_");
  };
}

1;