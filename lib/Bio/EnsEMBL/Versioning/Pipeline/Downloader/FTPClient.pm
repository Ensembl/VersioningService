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

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::FTPClient;

use Moose::Role;

use Net::FTP;
use LWP::UserAgent;
use URI;
use Cwd;
use File::Basename;
use Bio::EnsEMBL::Mongoose::NetException;
use Try::Tiny;
use Method::Signatures;

has ftp => (
  isa => 'Net::FTP',
  is => 'rw',
  predicate => 'connected_to_ftp',
);

with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::NetClient';

method connect_to_ftp_site ($url, $user, $password){
  my $ftp = Net::FTP->new($url->host);
  $ftp->login($user,$password) or Bio::EnsEMBL::Mongoose::NetException->throw("Cannot log into FTP site $url with $user:$password");
  $self->ftp($ftp);
}

=head2 get_ftp_files

  Arg [1]     : The URL to find the files at
  Arg [2]     : Filename pattern. This can be explicit or a regex pattern.
  Arg [3]     : [Optional] download path, somewhere to force the downloaded data to go
  Arg [4]     : User name for awkward FTP sites
  Arg [5]     : Password for even more awkward FTP sites

  Description : Given a ftp resource, returns the corresponding file or files
  Returntype  : listref of File paths to the downloaded resources
  Exceptions  : Throw on FTP get failed, or insufficient arguments.
  Caller      : internal

=cut

method get_ftp_files (
    Str $host_URL, 
    Str $filename_pattern, 
    Str $path = cwd(),
    Str $user = 'anonymous', 
    Str $password = '-anonymous@')
{
  unless ($host_URL && $filename_pattern) { Bio::EnsEMBL::Mongoose::NetException->throw("Insufficient arguments to download");}
  my $result;
  my $uri = URI->new($host_URL);
  unless ($self->connected_to_ftp) {
    $self->connect_to_ftp_site($uri,$user,$password);
  }
  $self->ftp->cwd($uri->path()) or Bio::EnsEMBL::Mongoose::NetException->throw("Unable to change to remote directory ".$uri->path." on server ".$uri->host);
  my @candidates = @{ $self->ls_ftp_dir($uri) };
  my @files;
  foreach my $file (@candidates) {
    if ($file =~ /$filename_pattern/) {
      print "Pattern matched $file\n";
      my $download_name = $path . '/' . $file;
      
      my $success = retry_sleep( sub {
        $self->ftp->binary;
        my $response = $self->ftp->get($file,$download_name);
        unless ($response) {print $self->ftp->message."\n"; return}
          else {return $response}
      }, 2   );

      if ($success) { push @files, $download_name} else { $self->close_ftp; Bio::EnsEMBL::Mongoose::NetException->throw("Incomplete download for $host_URL $filename_pattern") }; 
    }
  }
  return \@files;
}

method read_ftp_file ($uri) {
  # tried to use Net::FTP, but too convoluted for the end result.
  my $ua = LWP::UserAgent->new();
  $ua->env_proxy;
  my $response = $ua->get($uri);
  return $response->content if $response->is_success;
  Bio::EnsEMBL::Mongoose::NetException->throw('Unable to get FTP file content, '.$response->status_line. ' for '.$uri);
}

method ls_ftp_dir ($uri, $user = 'anonymous', $password = '-anonymous@') {
  unless ($uri->isa('URI')) { $uri = URI->new($uri) }
  unless ($self->connected_to_ftp) {
    $self->connect_to_ftp_site($uri,$user,$password);
  }
  if (!$self->ftp->cwd($uri->path())) {
    $self->close_ftp;
    Bio::EnsEMBL::Mongoose::NetException->throw('Cannot navigate to path on FTP host '.$uri->path);
  }
  my $files = $self->ftp->ls();
  return $files;
}

method get_timestamp ($uri,$file,$user = 'anonymous' ,$password = '-anonymous@') {
  unless ($uri->isa('URI')) { $uri = URI->new($uri) }
  unless ($self->connected_to_ftp) {
    $self->connect_to_ftp_site($uri,$user,$password);
  }
  $self->ftp->cwd($uri->path()) or Bio::EnsEMBL::Mongoose::NetException->throw("Unable to change to remote directory ".$uri->path." on server ".$uri->host);
  my $time = $self->ftp->mdtm($file);
  return $time;
}

sub close_ftp {
  my $self = shift;
  $self->ftp->quit;
}

1;
