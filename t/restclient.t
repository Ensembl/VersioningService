# Test the REST interface against ensembl REST server
use Test::More;
use Bio::EnsEMBL::Versioning::Pipeline::Downloader::RESTClient;
use IO::File;

package Thingy;

use Moose;
with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::RESTClient';


package main;

my $rest = Thingy->new;
is ( $rest->get_json(host => 'http://rest.ensembl.org/', path => 'info/ping', accepts => 'application/json'), '{"ping":1}','Test client against REST ping' );
is ( $rest->get_json(method => 'GET', host => 'http://rest.ensembl.org/', path => 'info/ping', accepts => 'application/json'), '{"ping":1}','Test REST ping with explicit GET' );

# test write-to-file behaviour
use Cwd;
my $expected_path = cwd().'/ping.json';
ok( $rest->get_json(host => 'http://rest.ensembl.org/', 
                    path => 'info/ping', 
                    accepts => 'application/json', 
                    file_path => cwd(), 
                    file_name => 'ping'), 'Write REST response to file' );
ok (-e $expected_path, 'Check correct extension, and that the file is there');

local $\ = '';
my $fh = IO::File->new($expected_path, 'r');
my $content = <$fh>;
is ($content, '{"ping":1}','File contains content');
$fh->close;

unlink($expected_path);

$content = $rest->get_json(method => 'GET', host => 'http://rest.ensembl.org/', path => 'info/ping', accepts => 'text/xml', content_type => 'text/xml');

my $xml = qq(<opt>\n  <data ping="1" />\n</opt>\n);
is($content, $xml, 'Check xml return value survived REST');

done_testing;