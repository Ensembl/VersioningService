use strict;
use warnings;

use Test::More;
use Test::Exception;

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

my $source = Bio::EnsEMBL::Versioning::Object::Source->new(name => 'UniProt');
$source->source_group(name => 'UniProtGroup');
$source->save();

my $resource = Bio::EnsEMBL::Versioning::Object::Resources->new(name => 'uniprot_ftp', type => 'ftp', value => 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/knowledgebase/uniprot_trembl.dat.gz');
$resource->source_download(module => 'UniProtParser');
$resource->source_download->source(name => 'UniProt');
$resource->save();

my $version_resource = Bio::EnsEMBL::Versioning::Object::Resources->new(name => 'uniprot_version', type => 'ftp', value => 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/knowledgebase/reldate.txt');
$resource->source_download(module => 'UniProtParser');
$resource->source_download->source(name => 'UniProt');

my $version = Bio::EnsEMBL::Versioning::Object::Version->new(version => '2013_12', record_count => 49243530, is_current => 1, uri => '/lustre/scratch110/ensembl/mr6/Uniprot/203_12/uniprot.txt');
$version->source(name => 'Uniprot');
$version->source->source_group(name => 'UniprotGroup');
$version->save();

