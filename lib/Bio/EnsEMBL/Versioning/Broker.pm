
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


# A singleton that provides the interface for the versioning service.
# It can retrieve different versions of a particular source as well as add
# new versions of sources to the versioning service.

package Bio::EnsEMBL::Versioning::Broker;

use Moose;
use Method::Signatures;
use Moose::Util::TypeConstraints;
use Module::Load::Conditional qw/can_load/;
use Env;
use Config::General;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;
use File::Copy;
use File::Spec;
use IO::Dir;
use Data::Dumper;

use Try::Tiny;
use Class::Inspector;
use Bio::EnsEMBL::Mongoose::DBException;
use Bio::EnsEMBL::Mongoose::UsageException;
use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::Versioning::ORM::Schema;

has config_file => (
    isa => 'Str',
    is => 'ro',
    required => 1,
    default => sub {
        return "$ENV{MONGOOSE}/conf/manager.conf";
    }
);

has config => (
    isa => 'HashRef',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $conf = Config::General->new($self->config_file);
        my %opts = $conf->getall();
        return \%opts;
    },
);
# set flag for testing or deployment, see also Versioning::TestDB
has create => (
  isa => 'Bool',
  is => 'ro',
  default => 0
);

has schema => (
  isa => 'Bio::EnsEMBL::Versioning::ORM::Schema',
  is => 'ro',
  lazy => 1,
  builder => 'init_broker'
);

# Subtype used to validate creation of new sources
subtype 'PackageName',
  as 'Str',
  message { "Provided package name does not resolve to a valid package in PERL5LIB" },
  where { can_load(modules => ({$_ => undef})) };


with 'MooseX::Log::Log4perl';


# A bunch of these DBIx::Class queries could be abstracted into the Schema classes for neatness.

sub init_broker {
  my $self = shift;
  my %conf = %{ $self->config };
  my %opts; 
  $opts{mysql_enable_utf8} = 1 if ($conf{driver} eq 'mysql');
  $opts{pg_enable_utf8 } = 1 if ($conf{driver} eq 'Pg');
  $opts{sqlite_unicode} = 1 if($conf{driver} eq 'SQLite');
  my $dsn; 
  if ($conf{driver} eq 'SQLite') { 
    $dsn = sprintf("dbi:%s:database=%s",$conf{driver},$conf{file}); 
  } else {
    $dsn = sprintf("dbi:%s:database=%s;host=%s;port=%s",$conf{driver},$conf{db},$conf{host},$conf{port}); 
  }
  my $schema = Bio::EnsEMBL::Versioning::ORM::Schema->connect(
    $dsn, 
    $conf{user}, 
    $conf{pass},
    { %opts },
  );
  $schema->deploy({ add_drop_table => 1}) if ($self->create() == 1);
  $self->log->debug("Connected to $dsn");
  return $schema;
}

# supply a temp folder for downloading to.
sub temp_location {
    my $self = shift;
    my $root = $self->config->{temp};
    my $dir = tempdir(DIR => $root, CLEANUP => 0);
    return $dir;
}


# generate a storage folder derived from the type and version of a source
sub location {
    my $self = shift;
    my $source = shift;
    my $revision = shift;

    my $root = $self->config->{home};
    my $path = $root.'/'.$source->source_groups->name.'/'.$source->name().'/'.$revision;
    make_path($path, { mode => '0774' });
    return $path;
}

# Move downloaded files from temp folder to a more permanent location, and update the versioning service to match.
method finalise_download ($source, Str $revision, Str $temp_location){
    my $final_location = $self->location($source,$revision);
    for my $file (glob $temp_location."/*") {
        move($file, $final_location.'/') || Bio::EnsEMBL::Mongoose::IOException->throw('Error moving files from temp space:'.$temp_location.' to '.$final_location.'. '.$@);
    }
    
    my $version = $self->schema->resultset('Version')->create( {
      revision => $revision,
      uri => $final_location,
      sources => $source, 
      count_seen => 1
    });

    return $final_location;
}

method get_current_version_of_source ( Str $source_name ) {
    my $source_rs = $self->schema->resultset('Source')->search(
      { name => $source_name },
      { join => 'current_version', rows => 1 }
    )->first;
    my $version;
    if ($source_rs) {
      $version = $source_rs->current_version;
    }
    return $version;
}

sub list_versions_by_source {
    my $self = shift;
    my $source_name = shift;
    unless ($source_name) {Bio::EnsEMBL::Mongoose::UsageException->throw('Versions of a source demand an actual source')};
    my $result = $self->schema->resultset('Source')->search_related('versions', {name => $source_name});
    my @versions = $result->all;
    if (scalar(@versions) == 0) { Bio::EnsEMBL::Mongoose::DBException->throw('No versions found for source: '.$source_name.'. Possible integrity issue')};
    my $revisions = [ map {$_->revision} @versions ];
    return $revisions;
}

method get_version_of_source (Str $source_name, Str $version){
    my $result = $self->schema->resultset('Version')->search(
      { 'sources.name' => $source_name, revision => $version },
      { join => 'sources' }
    );
    my $version_rs = $result->single;
    if (! $version_rs) { Bio::EnsEMBL::Mongoose::DBException->throw('No source: '.$source_name.' found with version '.$version)}
    return $version_rs;
}

method get_index_by_name_and_version (Str $source_name, Maybe[Str] $version? ){
  {
    no warnings;
    $self->log->info('Fetching index: '.$source_name.'  '.$version);
  }
  my $version_rs;
  if (defined $version) {
    $version_rs = $self->get_version_of_source($source_name,$version); 
  } else { 
    $version_rs = $self->get_current_version_of_source($source_name);
  }
  unless ($version_rs) { Bio::EnsEMBL::Mongoose::DBException->throw('Version '.$version.'of source '.$source_name.' is not in the versioning database')}
  return $version_rs->index_uri;
}

sub get_source {
  my $self = shift;
  my $source_name = shift;
  my $result = $self->schema->resultset('Source')->search(
    { name => $source_name }
  );
  return $result->first;
}

sub get_active_sources {
    my $self = shift;
    my $result = $self->schema->resultset('Source')->search(
      { active => 1}
    );
    return [ $result->all ];
}

sub get_file_list_for_version {
  my $self = shift;
  my $version = shift;
  my $dir = $version->uri;
  my @files = glob($dir.'/*');
  # print "Found files: ".join(',',@files);
  return \@files;
}

sub document_store {
  my $self = shift;
  my $path = shift;
  my $doc_store_package = $self->config->{'doc_store'};
  unless ($doc_store_package) { Bio::EnsEMBL::Mongoose::UsageException->throw('Document store undefined in config. Specify doc_store = package::name ')}
  $self->get_module($doc_store_package);
  if ($path) {
    return $doc_store_package->new(index => $path);
  } else {
    return $doc_store_package->new(index => $self->temp_location);
  }
}

# finalise_index moves the index out of temp and into a permanent location
method finalise_index ($source, $revision, $doc_store, Int $record_count){
  my $temp_path = $doc_store->index;
  my $temp_location = IO::Dir->new($temp_path);
  my $final_location = $self->location($source,$revision);
  $self->log->debug("Moving index from $temp_path to $final_location");
  while (my $file = $temp_location->read) {
    next if $file =~ /^\.+$/;
    make_path(File::Spec->catfile($final_location,'index'), { mode => '0774' });
    move(File::Spec->catfile($temp_path,$file), File::Spec->catfile($final_location,'index',$file) )
      || Bio::EnsEMBL::Mongoose::IOException->throw('Error moving index files from temp space:'.$temp_path.'/'.$file.' to '.$final_location.'index/  '.$!);
  }
  my $version_set = $self->schema->resultset('Version')->find(
      { revision => $revision }
  );
  $version_set->index_uri(File::Spec->catfile($final_location,'index'));
  $version_set->record_count($record_count);
  $self->log->debug("Saved index to $final_location with $record_count entries");
  $version_set->update;

  $source->current_version($version_set);
  $source->update;
}

method add_new_source (Str $name,Str $group_name,Bool $active,PackageName $downloader,PackageName $parser) { 
  return $self->schema->resultset('Source')->create({
    name => $name,
    source_groups => { name => $group_name },
    active => $active,
    downloader => $downloader,
    parser => $parser
  });
}

sub get_downloader {
  my $self = shift;
  my $name = shift;
  my $source_rs = $self->schema->resultset('Source')->search( { name => $name } )->first;
  unless ($source_rs) { Bio::EnsEMBL::Mongoose::UsageException->throw("Cannot find source $name to supply downloader module") }
  return $source_rs->downloader;
}


# imports modules required for accessing the document store of choice, e.g. Lucy
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

__PACKAGE__->meta->make_immutable;

1;