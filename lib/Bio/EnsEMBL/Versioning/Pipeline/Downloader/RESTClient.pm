package Bio::EnsEMBL::Versioning::Pipeline::Downloader::RESTClient;

use Moose::Role;

use Cwd;
use File::Basename;
use Bio::EnsEMBL::Mongoose::NetException;
use Try::Tiny;
use Method::Signatures;
use REST::Client; # slight overkill, but we might have to authenticate requests in future

with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::NetClient';

=head2 get_json

  Arg [1]     : The URL of the service
  Arg [2]     : The command chained below the service
  Arg [3]     : [Optional] download path, somewhere to force the downloaded data to go

  Description : Given a REST server, command and parameters, it returns the corresponding data
  Returntype  : listref of File paths to the downloaded resources
  Exceptions  : Throw on failure of remote request
  Caller      : internal

=cut

method get_json (
    Str $host_URL, 
    Str $command,
    $path?,
    )
{
  my $rest = REST::Client->new;
  $rest->setHost($host_URL);
  
  my $response;

  retry_sleep( sub {
    $rest->GET($command);
    if ($rest->responseCode eq '200') {
      $response = $rest->responseContent;
      return 1;
    }
    
  }, 2,10);
  if ($path) {

  } else {
    return $response;
  }
}

1;