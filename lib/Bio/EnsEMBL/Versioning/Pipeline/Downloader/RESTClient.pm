package Bio::EnsEMBL::Versioning::Pipeline::Downloader::RESTClient;

use Moose::Role;

use Cwd;
use File::Basename;
use Bio::EnsEMBL::Mongoose::NetException;
use Try::Tiny;
use Method::Signatures;
use REST::Client; # slight overkill, but we might have to authenticate requests in future
use IO::File;
use File::Spec;
use Bio::EnsEMBL::Mongoose::IOException;

with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::NetClient';

=head2 get_json

  Arg [host]     : The URL of the service
  Arg [method]   : The commands chained below the service
  Arg [file_path]: [Optional] somewhere to force the downloaded data to go
  Arg [file_name]: [Optional] when a specific file name is required 
  Arg [content_type]: [Optional] declare the content-type of the message. Sets the header accordingly
  Arg [bodge]    : [Optional] conflate accepts and content-type headers
  Arg [body]     : [Optional] content for POST or PUT requests

  Description : Given a REST server, command and parameters, it returns the corresponding data
  Returntype  : listref of File paths to the downloaded resources
  Exceptions  : Throw on anything other than 200 for the remote request
  Caller      : internal

=cut

method get_json (
    Str :$host, 
    Str :$method = 'GET',
    Str :$path,
    :$file_path,
    :$file_name = 'download',
    :$content_type = 'application/json',
    :$accepts = 'application/json',
    :$retry_delay = 10,
    :$retry_attempts = 2,
    :$bodge,
    :$body
    )
{
  my $rest = REST::Client->new;
  $rest->setHost($host);
  $rest->setTimeout(30); # default medium-long for response
  $rest->addHeader('Content-Type', $content_type);
  if ($bodge) { $rest->addHeader('accepts',$content_type)}
  $rest->addHeader('accepts',$accepts);
  my $response;

  retry_sleep( sub {
    $rest->$method($path, $body);
    if ($rest->responseCode eq '200') {
      $response = $rest->responseContent;
      return 1;
    } else {
      print "HTTP error code ".$rest->responseContent."\n";
    }
    
  }, $retry_attempts,$retry_delay);

  if ($file_path && $response) {
    my $extension;
    # crudely limited to json vs xml at the mo.
    # print $accepts."\n";
    $extension = ($accepts =~ /json/) ? '.json' : '.xml';
    # print $extension."\n";
    my $canonical_file = File::Spec->catfile($file_path,$file_name.$extension);
    my $fh = IO::File->new($canonical_file, 'w') || Bio::EnsEMBL::Mongoose::IOException->throw($@);
    print $fh $response || Bio::EnsEMBL::Mongoose::IOException->throw($@);
    $fh->close;
  } else {
    return $response;
  }
}

1;