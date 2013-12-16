use strict;
use warnings;

use Bio::EnsEMBL::Versioning::DB;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
-host => 'my_host',
-species => 'multi',
-group => 'versioning',
-user => 'my_user',
-pass => 'XXX',
-dbname => 'my_db'
);
Bio::EnsEMBL::Versioning::DB->register_DBAdaptor($dba);

require Bio::EnsEMBL::Versioning::Manager::Version;
require Bio::EnsEMBL::Versioning::Manager::Process;
require Bio::EnsEMBL::Versioning::Manager::Source;
require Bio::EnsEMBL::Versioning::Manager::SourceGroup;
require Bio::EnsEMBL::Versioning::Manager::SourceDownload;
require Bio::EnsEMBL::Versioning::Manager::Resources;
require Bio::EnsEMBL::Versioning::Manager::Run;

my $source = Bio::EnsEMBL::Versioning::Object::Source->new(name => 'RefSeq');
$source->source_group(name => 'RefSeq');
$source->save();

my $resource = Bio::EnsEMBL::Versioning::Object::Resources->new(name => 'refseq_file', type => 'file', value => 'refseq.txt');
$resource->source_download(module => 'RefSeqParser');
$resource->source_download->source(name => 'RefSeq');
$resource->save();

my $version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '12', record_count => 350, is_current => 1);
$version->source(name => 'Uniprot');
$version->source->source_group(name => 'UniprotGroup');
$version->save();


my $run = Bio::EnsEMBL::Versioning::Object::Run->new(start => 'now()');
$run->version($version);
$run->save();
my $process = Bio::EnsEMBL::Versioning::Object::Process->new(name => 'update');
$process->run($run);
$process->save();

my $second_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '11', record_count => 999);
$second_version->source(name => 'Uniprot');
$second_version->save();

my $third_version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '12', record_count => 238, is_current => 1);
$third_version->source(name => 'UniprotTrEMBL');
$third_version->source->source_group(name => 'UniprotGroup');
$third_version->save();

