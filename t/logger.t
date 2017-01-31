=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

use strict;
use warnings;

use Test::More;
use Bio::EnsEMBL::Versioning::Logger;
use Bio::EnsEMBL::Versioning::TestDB qw/broker get_conf_location/;
use Time::HiRes qw (sleep);


my $broker = broker();

#add uniprot
my $uniprot_version = $broker->schema->resultset('Version')->create({revision => '2013_12', record_count => 49243530, uri => '/lustre/scratch110/ensembl/Uniprot/203_12/uniprot.txt', count_seen => 1});
ok($uniprot_version->version_id eq 1, "Has version_id ". $uniprot_version->version_id);

#$broker->schema->storage->debug(1); uncomment to see sql statements
my $uniprot_group = $broker->schema->resultset('SourceGroup')->create({ name => 'UniProtGroup' });
my $uniprot_source = $uniprot_group->create_related('sources', {name=> 'UniProt/SWISSPROT', parser => 'UniProtParser', current_version => $uniprot_version, active => 1, downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniProtSwissProt'});

# Connect version to source now that it exists
$uniprot_version->sources($uniprot_source);
$uniprot_version->update;

ok($uniprot_source->in_storage(),"Source created in DB");
ok($uniprot_version->in_storage(),"Version created in DB");
ok($uniprot_group->in_storage(),"Group created in DB");

#add reactome
my $reactome_version = $broker->schema->resultset('Version')->create({revision => '2017_01', record_count => 49243530, uri => '/lustre/scratch110/ensembl/Reactome/2017_01/reactome.txt', count_seen => 1});
ok($reactome_version->version_id eq 2, "Has version_id $reactome_version");

my $reactome_group = $broker->schema->resultset('SourceGroup')->create({ name => 'ReactomeGroup' });
my $reactome_source = $reactome_group->create_related('sources', {name=> 'Reactome', parser => 'ReactomeParser', current_version => $reactome_version, active => 1, downloader => 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::Reactome'});

# Connect version to source now that it exists
$reactome_version->sources($reactome_source);
$reactome_version->update;

ok($reactome_source->in_storage(),"Source created in DB");
ok($reactome_version->in_storage(),"Version created in DB");
ok($reactome_group->in_storage(),"Group created in DB");


my @sources = @{ $broker->get_active_sources };
ok(scalar @sources == 2, 'Found one active source');

is($broker->get_current_version_of_source('UniProt/SWISSPROT')->version_id, $uniprot_version->version_id, 'version set correctly for source');
is($broker->get_current_version_of_source('Reactome')->version_id, $reactome_version->version_id, 'version set correctly for source');

my $logger = Bio::EnsEMBL::Versioning::Logger->new(config_file=>get_conf_location(), create => 0);

#begin run
my ($run_id) = $logger->log_run(begin_run=>1, end_run=>0, run_id=>0);

#wait for 2 seconds
sleep(2);
#end run
($run_id) = $logger->log_run(begin_run=>1, end_run=>1, run_id=>$run_id);


my $run_rs = $broker->schema->resultset('Run')->search->first;
ok(($run_rs->end - $run_rs->start)->seconds == 2, "Got the right time difference between start and end");

#prefix run_id with me otherwise you will get DBI exception
#DBI Exception: DBD::SQLite::db prepare_cached failed: ambiguous column name: run_id
my $version_run_rs = $broker->schema->resultset('Run')->search(
      { 'me.run_id' => $run_rs->run_id },
      { join => 'version_runs'}
    )->first;
    

my $version_run = $version_run_rs->version_runs->first;
ok($version_run->version_id, "Got the right version_id");
ok($version_run->run_id == $run_rs->run_id, "Got the right run_id");

my $versions = $broker->get_versions_for_run($run_id);
ok(scalar(@{$versions}) == 2, "Got back two versions");
my $version1 = shift @$versions;
my $version2 = shift @$versions;

ok($version1->version_id == 1, "Got back version_id  for source1");
ok($version1->revision eq '2013_12', "Got back revision for source1");

ok($version2->version_id == 2, "Got back version_id for source2");
ok($version2->revision eq '2017_01', "Got back revision for source2");


my $version_uniprot_source = $broker->get_version_for_run_source($run_id, $uniprot_source->name);
ok($version_uniprot_source->revision eq '2013_12', "revision ok for uniprot");

my $version_reactome_source = $broker->get_version_for_run_source($run_id, $reactome_source->name);
ok($version_reactome_source->revision eq '2017_01', "revision ok for reactome");

my $base_path = '/tmp';
$run_id = 206;
my $species = "homo sapiens";
my $full_path = File::Spec->join( $base_path, "xref_rdf_dumps", $run_id, $species);
print "$full_path\n";
done_testing;
