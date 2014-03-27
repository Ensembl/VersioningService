package Bio::EnsEMBL::Versioning::Pipeline::Downloader::FTPClient;

use Moose::Role;

use Bio::EnsEMBL::Utils::Net qw/do_FTP_to_file/;
use Net::FTP;
use URI;
use Cwd;
use File::Basename;
use Bio::EnsEMBL::Mongoose::NetException;
use Try::Tiny;

=head2 get_ftp_files

  Arg [1]     : The URL to find the files at
  Arg [2]     : Filename pattern. This can be explicit or a regex pattern.
  Arg [3]     : [Optional] download path, somewhere to force the downloaded data to go
  Example     :
  Description : Given a ftp resource, returns the corresponding file or files
  Returntype  : listref of File paths to the downloaded resources
  Exceptions  : Throw on FTP get failed.
  Caller      : internal

=cut


sub get_ftp_files
{
  my $self = shift;
  my $host_URL = shift;
  my $filename_pattern = shift;
  my $path = shift;

  $path ||= cwd();
  unless ($host_URL && $filename_pattern) { Bio::EnsEMBL::Mongoose::NetException->throw("Insufficient arguments to download");}
  my $result;
  my $uri = URI->new($host_URL);
  
  my @candidates = @{ $self->ls_ftp_dir($uri) };
  my @files;
  foreach my $file (@candidates) {
    if ($file =~ /$filename_pattern/) {
      print "Pattern matched $file.\n";
      my $download_name = $path . '/' . $file;
      try { 
        do_FTP_to_file($host_URL.'/'.$file, undef, undef, $download_name); 
      }
      catch {
        Bio::EnsEMBL::Mongoose::NetException->throw($_);
      };
      push @files, $download_name;
    }
  }
  return \@files;
}

sub ls_ftp_dir
{
  my $self = shift;
  my $uri = shift;
  unless ($uri->isa('URI')) { $uri = URI->new($uri) }

  my $ftp = Net::FTP->new($uri->host());
  if (!$ftp->login('anonymous', '-anonymous@')) {
    Bio::EnsEMBL::Mongoose::NetException->throw('Cannot log into FTP host '.$uri->host);
  }
  if (!$ftp->cwd($uri->path())) {
    Bio::EnsEMBL::Mongoose::NetException->throw('Cannot navigate to path on FTP host '.$uri->path);
  }
  my $files = $ftp->ls();
  return $files;
}

# pass-through method to allow Role methods to cross over
sub do_FTP {
  return Bio::EnsEMBL::Utils::Net::do_FTP(@_);
}

1;