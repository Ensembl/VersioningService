=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 DESCRIPTION

The Broker provides the interface for the versioning service.
It can retrieve different versions of a particular source as well as add
new versions of sources to the versioning service.

Any requests for indexes or sources go through the broker.

=cut


package Bio::EnsEMBL::Versioning::Broker;

use Moose;
use Method::Signatures;
use Moose::Util::TypeConstraints;
use Module::Load::Conditional qw/can_load/;
use Env;
use Config::General;
use File::Temp qw/tempdir/;
use File::Path qw/make_path remove_tree/;
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

# Subtype used to validate source arguments to certain methods where the ORM object is required
subtype Source => as 'Object'
  => message { 'This method requires a Source object from the ORM' }
  => where { $_->isa('Bio::EnsEMBL::Versioning::ORM::Schema::Result::Source') };

has scratch_space => (
  isa => 'Str',
  is => 'rw',
  lazy => 1,
  builder => 'get_scratch_path'
);


with 'MooseX::Log::Log4perl';


# A bunch of these DBIx::Class queries could be abstracted into the Schema classes for neatness.

sub init_broker {
  my $self = shift;
  my %conf = %{ $self->config };
  my %opts;
  unless (defined $ENV{MONGOOSE}) { die 'Versioning Service must have environment variable $MONGOOSE set to root of code' }
  $opts{mysql_enable_utf8} = 1 if ($conf{driver} eq 'mysql');
  $opts{pg_enable_utf8} = 1 if ($conf{driver} eq 'Pg');
  $opts{sqlite_unicode} = 1 if($conf{driver} eq 'SQLite');
  my $dsn; 
  if ($conf{driver} eq 'SQLite') { 
    $dsn = sprintf("dbi:%s:database=%s",$conf{driver},$conf{file}); 
  } else {
    $dsn = sprintf("dbi:%s:database=%s;host=%s;port=%s",$conf{driver},$conf{db},$conf{host},$conf{port}); 
  }
  $self->log->debug("Connecting to $dsn");

  my $schema = Bio::EnsEMBL::Versioning::ORM::Schema->connect(
    $dsn, 
    $conf{user}, 
    $conf{pass},
    { %opts },
  );
  $schema->deploy({ add_drop_table => 1}) if ($self->create() == 1);
  return $schema;
}

sub get_scratch_path {
  my $self = shift;
  if (exists $self->config->{scratch_space} && -w $self->config->{scratch_space}) {
    return $self->config->{scratch_space};
  } else {
    Bio::EnsEMBL::Mongoose::IOException->throw("scratch_space not defined or writeable in config file ".$self->config_file);
  }
}

# supply a temp folder for downloading to.
sub temp_location {
    my $self = shift;
    my $root = $self->config->{temp};
    my $dir = tempdir(DIR => $root, CLEANUP => 1);
    $self->log->debug("New download folder: $dir");
    return $dir;
}

# generate a storage folder derived from the type and version of a source
sub location {
    my $self = shift;
    my $source = shift;
    my $revision = shift;

    my $root = $self->config->{home};
    my $path = $root.'/'.$source->source_groups->name.'/'.$source->name().'/'.$revision;
    make_path($path, { mode => 0774 });
    $self->log->debug("New final storage location for ".$source->name.":$revision at $path");
    return $path;
}

# returns a list of paths to files that have been copied to scratch space. By default the copies
# will be cleaned up after the process terminates.
sub shunt_to_fast_disk {
  my ($self,$things_to_move,$do_not_delete) = @_;
  my $conf = $self->config;

  my @file_list;
  if (ref $things_to_move eq 'ARRAY') {
    @file_list = @$things_to_move;
  } else {
    push @file_list,$things_to_move;
  }
  my $scratch = $self->scratch_space;
  my @copies;
  if (-d $scratch && -w $scratch) {
    my $tmp_dir = tempdir(DIR => $scratch, CLEANUP => !$do_not_delete);
    foreach my $file (@file_list) {
      my ($vol,$dir,$filename) = File::Spec->splitpath($file);
      my $copy_name = File::Spec->catfile($tmp_dir,$filename);
      copy($file,$copy_name) || Bio::EnsEMBL::Mongoose::IOException->throw("Unable to copy to scratch space for parsing $!");
      $self->log->debug("Copying $filename to scratch space: $copy_name");
      push @copies, $copy_name;
    }
    return \@copies;
  } else {
    $self->log->warn('No configuration for fast disk, leaving files where they are');
    return $things_to_move;
  }
}

# Move downloaded files from temp folder to a more permanent location, and update the versioning service to match.
method finalise_download (Source $source, Str $revision, Str $temp_location){
    my $final_location = $self->location($source,$revision);
    $self->log->debug(sprintf "Moving new %s index from %s to %s",$source->name,$temp_location,$final_location);
    for my $file (glob $temp_location."/*") {
      `mv $file $final_location/`;
      if ($? >> 8 != 0) {Bio::EnsEMBL::Mongoose::IOException->throw('Error moving files from temp space:'.$temp_location.' to '.$final_location.'. '.$!)};
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
    my $source_rs = $self->schema->resultset('Source')->find(
      { name => $source_name },
      { prefetch => 'current_version', rows => 1 }
    );
    my $version;
    if ($source_rs) {
      $version = $source_rs->current_version;
      $self->log->debug("Latest version of source $source_name is ".$version->revision);
      return $version;
    }
    return;
}

method set_current_version_of_source ( Str $source_name, Str $revision) {
  # Update the "current version" when all sub-indexes have been added to the set, not after each and every one.
  my $source = $self->schema->resultset('Source')->find(
    { name => $source_name },
  );

  my $version = $self->schema->resultset('Version')->find(
    { revision => $revision, 'sources.name' => $source_name },
    { join => 'sources' }
  );
  $self->log->debug("Current version = ".$source->current_version);
  $self->log->debug("New version = ".$version->uri);
  $source->update_from_related('current_version', $version);
}

sub list_versions_by_source {
    my $self = shift;
    my $source_name = shift;
    unless ($source_name) {Bio::EnsEMBL::Mongoose::UsageException->throw('Versions of a source demand an actual source')};
    my $result = $self->schema->resultset('Source')->search_related('versions', {name => $source_name});
    my @versions = $result->all;
    if (scalar(@versions) == 0) { Bio::EnsEMBL::Mongoose::DBException->throw('No versions found for source: '.$source_name.'. Possible integrity issue')};
    my $revisions = [ map {$_->revision} @versions ];
    $self->log->debug("$source_name has the following versions: ".join ',',@$revisions);
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
  return $version_rs->get_all_index_paths;
}

sub get_source {
  my $self = shift;
  my $source_name = shift;
  my $result = $self->schema->resultset('Source')->find(
    { name => $source_name }
  );
  return $result;
}

sub get_active_sources {
    my $self = shift;
    my $result = $self->schema->resultset('Source')->search(
      { active => 1}
    );
    return [ $result->all ];
}

sub get_versions_for_run {
    my $self = shift;
    my $run_id = shift;
    my $result = $self->schema->resultset('VersionRun')->search(
      { run_id => $run_id}
    )->related_resultset('versions');
    return [ $result->all ];
}

sub get_version_for_run_source {
    my $self = shift;
    my $run_id = shift;
    my $source_name = shift;

    my $result = $self->schema->resultset('VersionRun')->search(
                           { run_id => $run_id}
                           )->related_resultset('versions')->search(
                           { 'sources.name' => $source_name },
                           { join => 'sources' }
    );
    my $version = $result->single;
    return $version;
}

sub get_file_list_for_version {
  my $self = shift;
  my $version = shift;
  my $dir = $version->uri;
  my @files = glob($dir.'/*');
  @files = grep { $_ !~ /index$/ } @files; # Remove any possible overlap with output of a previous parsing attempt
  $self->log->debug("Parsing files: ".join(',',@files));
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
# Can be one of several indexes for the same source when generated in parallel
method finalise_index (Source $source, Str $revision, $doc_store, Int $record_count){
  my $temp_path = $doc_store->index;
  my $temp_location = IO::Dir->new($temp_path);
  my $final_location = $self->location($source,$revision);
  my $index_location = File::Spec->catfile($final_location,'index');
  $self->log->debug("Somehow indexing of ".$source->name.":$revision finished without parsing any records: $record_count") if $record_count < 1;
  $self->log->debug("Moving index from $temp_path to $final_location");
  # Can no longer count on a pre-existing folder implying a failed previous attempt
  # if (-e $index_location) {
  #   remove_tree($index_location); # delete any existing attempts
  # }

  # Generate a safe sub-folder to put the new index in. Has to be resilient to race-conditions from multiple pipeline workers
  make_path($index_location, { mode => 0774 });
  my $index_subdir = tempdir(DIR => $index_location, CLEANUP => 0); # Please don't delete the not-so-temporary output
  
  while (my $file = $temp_location->read) {
    next if $file =~ /^\.+$/;
    my $source_dir = File::Spec->catfile($temp_path,$file);
    my $target = File::Spec->catfile($index_subdir,$file);
    my $result = `mv $source_dir $target`; # File::Copy cannot move folders between file systems
    if ($? >> 8 != 0) {
      Bio::EnsEMBL::Mongoose::IOException->throw("File moving failed: ".$!);
    }
  }
  $self->log->debug(sprintf "Fetching existing version %s for source %s\n",$revision,$source->name);
  my $version = $self->schema->resultset('Version')->find(
      { revision => $revision,
        'sources.name' => $source->name
      },
      { join => 'sources' }
  );
  $self->log->debug("Adding $record_count to index record count\n");
  $version->index_uri(File::Spec->catfile($final_location,'index')); # Set link to outer folder.
  # Increment record count by the new number. This may not be thread safe?
  $self->log->debug(sprintf "Existing record_count is %d\n",$version->record_count);
  if (defined $version->record_count) {
    $version->record_count($record_count + $version->record_count());
    $self->log->debug(sprintf "New record_count for index = %d\n",$version->record_count);
  } else {
    $version->record_count($record_count);
  }
  $self->log->debug("Added an index to $final_location with $record_count entries");

  $version->version_indexes->create({
    record_count => $record_count,
    index_uri => $index_subdir
  });

  $version->update();
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
  my $source_rs = $self->schema->resultset('Source')->find( { name => $name } );
  unless ($source_rs) { Bio::EnsEMBL::Mongoose::UsageException->throw("Cannot find source $name to supply downloader module") }
  return $source_rs->downloader;
}

# Increment count seen for a specific revision of a source
sub already_seen {
  my $self = shift;
  my $revision = shift;
  $revision->count_seen($revision->count_seen + 1);
  $revision->update()->discard_changes();
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
