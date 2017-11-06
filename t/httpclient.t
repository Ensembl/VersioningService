# Test the REST interface against ensembl REST server
use Test::More;
use Moose;
use Cwd;

use_ok 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HTTPClient';

package Thingy;

use Moose;
with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::HTTPClient';

package main;

my $http_client = Thingy->new;
my $test_host_url = "http://www.reactome.org/download/current/";
my $status = $http_client->connected_to_http($test_host_url);
ok($status, "Able to connect to $test_host_url");

my $file_names = ["create_reactome2biosystems.log"];
my $downloaded_files = $http_client->get_http_files(host_URL=>$test_host_url, filenames=>$file_names);
isa_ok($downloaded_files, 'ARRAY' );
ok(scalar(@$downloaded_files) == 1, "Got back 1 files");
ok($$downloaded_files[0] eq cwd().'/create_reactome2biosystems.log', "Got back the right file");
ok(-e cwd().'/create_reactome2biosystems.log', "File exists at ". cwd().'create_reactome2biosystems.log');

clean_up_files($downloaded_files);

ok(! -e cwd().'create_reactome2biosystems.log', "File do not exist at ". cwd().'create_reactome2biosystems.log');

sub clean_up_files {
  my $downloaded_files = shift;
  foreach my $file (@$downloaded_files){
    unlink $file;
  }

}


done_testing;