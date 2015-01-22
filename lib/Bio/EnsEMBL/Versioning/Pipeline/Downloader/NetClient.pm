package Bio::EnsEMBL::Versioning::Pipeline::Downloader::NetClient;

use Moose::Role;
use Time::HiRes;
use Bio::EnsEMBL::Mongoose::NetException;

# taken from Ensembl Utils/Net
sub retry_sleep {
  my ($callback, $total_attempts, $sleep) = @_;
  $total_attempts ||= 1;
  $sleep ||= 0;
  my $response;
  my $retries = 0;
  my $fail = 1;
  while($retries <= $total_attempts) {
    $response = $callback->();
    if(defined $response) {
      $fail = 0;
      last;
    }
    $retries++;
    Time::HiRes::sleep($sleep);
  }
  if($fail) {
    Bio::EnsEMBL::Mongoose::NetException->throw("Could not request remote resource after $total_attempts attempts");
  }
  return $response;
}

1;