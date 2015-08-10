use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Broker;
use Log::Log4perl;

Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

my $broker = Bio::EnsEMBL::Versioning::Broker->new(create => 1,config_file => "$ENV{MONGOOSE}/conf/manager.conf");

$broker->add_new_source('Swissprot','Uniprot',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtSwissProt','Bio::EnsEMBL::Mongoose::Parser::Swissprot');
$broker->add_new_source('Uniparc','Uniprot',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtUniParc','Bio::EnsEMBL::Mongoose::Parser::Uniparc');
$broker->add_new_source('Trembl','Uniprot',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtTrembl','Bio::EnsEMBL::Mongoose::Parser::Swissprot');
$broker->add_new_source('RefSeq','RefSeq',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq','Bio::EnsEMBL::Mongoose::Parser::RefSeq');
$broker->add_new_source('MIM','MIM',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM','Bio::EnsEMBL::Mongoose::Parser::MIM');
$broker->add_new_source('mim2gene','MIM',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::MIM2Gene','Bio::EnsEMBL::Mongoose::Parser::MIM2Gene');
$broker->add_new_source('HGNC','HGNC',1,'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HGNC','Bio::EnsEMBL::Mongoose::Parser::HGNC');

print "Created basic Xref working set of sources. Now enable the update pipeline to allow it to download the first copy of each source\n";
