=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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
