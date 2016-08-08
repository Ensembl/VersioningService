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

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Interface package for generic downloading of stuff.

package Bio::EnsEMBL::Versioning::Pipeline::Downloader;

use Moose;
use Bio::EnsEMBL::Mongoose::IOException;
use Time::gmtime;

=head2 get_version

  Example     : $downloader->get_version()
  Description : Determines the version of this resource
  Returntype  : String
  Caller      : internal

=cut

sub get_version {
    ...
}

=head2 download_to

  Example     : $downloader->download_to(/home/xref)
  Description : Performs all necessary work to download this resource to the supplied location
                Data is spooled to a temporary location, prior to being finalised in the given
                location
  Returntype  : Listref of file names retrieved
  Exceptions  : IOException in case of storage failures, download interruptions etc.
  Caller      : internal

=cut

sub download_to {
    my $self = shift;
    my $path = shift;

    unless (!$path || -w $path) {
        Bio::EnsEMBL::Mongoose::IOException->throw("Cannot write to download destination: $path");
    }
    $self->_get_remote($path);
}

sub timestamp {
  my $self = shift;
  my $gmt = gmtime();
  my $time = sprintf "%04u%02s%02s",$gmt->year + 1900,$gmt->mon,$gmt->mday;
  return $time;
}


=head2 _get_remote

  Example     : $downloader->_get_remote
  Description : Worker function, defined in each subclass of downloader. See module documentation.
  Returntype  : Listref of files downloaded and their paths
  Exceptions  : IOException in case of storage failures, download interruptions etc.
  Caller      : internal

=cut

sub _get_remote {
    # implement this for each downloader
    ...
}

1;