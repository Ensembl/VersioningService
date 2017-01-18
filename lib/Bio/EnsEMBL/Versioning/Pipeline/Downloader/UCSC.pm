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

=head1 NAME

Bio::EnsEMBL::Versioning::Pipeline::Downloader::RefSeq

=head1 DESCRIPTION

A module for UCSC specific downloading methods

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::UCSC;

use Moose;
use File::Copy;

extends 'Bio::EnsEMBL::Versioning::Pipeline::Downloader';

has host => (
  isa => 'Str', 
  is => 'ro',
  default => 'ftp://hgdownload.cse.ucsc.edu',
);

#
# list the assemblies (UCSC synonyms) for which we download data
# currently GRCh38 and GRCm38
#
has assemblies => (
  isa => 'ArrayRef[Str]',
  is  => 'ro',
  default => sub {
    [ 'hg38', 'mm10' ]
  }		     
);

has file_pattern => (
  isa => 'Str',
  is => 'rw', # to allow test runs
  default => 'knownGene.txt.gz',
);

with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::FTPClient','MooseX::Log::Log4perl';

sub get_version {
  return shift->timestamp;
}

sub _get_remote {
  my $self = shift;
  my $path = shift; # path is already checked as valid

  # here we download the data file for each one of the supported
  # assemblies listed in the assemblies instance variable
  my $results;
  foreach my $assembly (@{$self->assemblies}) {
    my $uri = sprintf "%s/goldenPath/%s/database/", $self->host, $assembly;
    my $result = $self->get_ftp_files($uri, $self->file_pattern, $path);
    $self->log->debug(sprintf "Downloaded UCSC FTP file: %s [%s]", $result->[0], $assembly);

    # rename the file with the UCSC assembly synonym so that the parser
    # is able to assign taxon ID
    my $dest = sprintf "%s/%s.txt.gz", $path, $assembly;
    my $source = $result->[0];
    move($source, $dest) or
      Bio::EnsEMBL::Mongoose::IOException->throw(sprintf "Cannot rename %s to %s", $source, $dest);
      
    push @{$results}, $dest;
  }
  
  return $results if (scalar @$results > 0);

  Bio::EnsEMBL::Mongoose::NetException->throw("No files downloaded from UCSC source");
}

__PACKAGE__->meta->make_immutable;

1;
