=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::HTTPClient;

use Moose::Role;

use LWP::Simple;
use Cwd;
use Try::Tiny;
use Method::Signatures;
use Bio::EnsEMBL::Mongoose::NetException;

with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::NetClient';

method connected_to_http ($url){
  my $status = LWP::Simple::head($url);
  return 1 if $status;
  return Bio::EnsEMBL::Mongoose::NetException->throw("Cannot connect to HTTP site $url");
}

=head2 get_http_files

  Arg [1]     : The URL to find the files at
  Arg [2]     : List of file names
  Arg [3]     : [Optional] download path, somewhere to force the downloaded data to go

  Description : Given a http resource, returns the corresponding file or files
  Returntype  : listref of File paths to the downloaded resources
  Exceptions  : Throw on HTTP get failed, or insufficient arguments.
  Caller      : internal

=cut

method get_http_files (
    Str :$host_URL, 
    ArrayRef[Str] :$filenames, 
    Str :$path = cwd())
{
  unless ($host_URL && $filenames) { Bio::EnsEMBL::Mongoose::NetException->throw("Insufficient arguments to download");}
  unless ($self->connected_to_http($host_URL)) { Bio::EnsEMBL::Mongoose::NetException->throw("Cannot connect to HTTP site $host_URL");}

  my @files;
  foreach my $filename (@$filenames) {
    my $file = $host_URL.$filename;
    my $file_store = $path . '/' . $filename;
    
    my $response_code = retry_sleep( sub {
        my $response = LWP::Simple::getstore( $file, $file_store );
        unless ($response) {print "Download Failed\n"; return}
          else {return $response}
      }, 2   );
    
    if ($response_code == 200) { push @files, $file_store} else { Bio::EnsEMBL::Mongoose::NetException->throw("Incomplete download for $host_URL $filename") }; 
    }
  
  return \@files;
}


1;