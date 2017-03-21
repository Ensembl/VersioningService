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

Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniGene - A class to download UniGene's Hs.seq.uniq file

=head1 DESCRIPTION

This is a class which is used to download the UniGene's Hs.seq.uniq file.
For more info about UniGene files, please refer: ftp://ftp.ncbi.nih.gov/repository/UniGene/Homo_sapiens/

grep '\bHs.34012\b' Hs.seq.uniq 
>gnl|UG|Hs#S1731803 Homo sapiens breast cancer 2, early onset (BRCA2), mRNA /cds=p(228,10484) /gb=NM_000059 /gi=119395733 /ug=Hs.34012 /len=11386
=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::UniGene;

use Moose;
use File::Slurp;
use File::Path qw/make_path remove_tree/;
use File::Copy;
use File::Basename;

extends 'Bio::EnsEMBL::Versioning::Pipeline::Downloader';

has uri => (
  isa => 'Str', 
  is => 'ro',
  default => 'ftp://ftp.ncbi.nih.gov/repository/UniGene/',
);

has file_pattern => (
  isa => 'Str',
  is => 'rw', # to allow test runs
  default => '.*?\.seq\.uniq\.gz'
  
);

with 'Bio::EnsEMBL::Versioning::Pipeline::Downloader::FTPClient','MooseX::Log::Log4perl';

sub get_version
{
  my $self = shift;
  return $self->timestamp;
}

=head
1) Get the README file from ftp://ftp.ncbi.nih.gov/repository/UniGene/README

2) Look for lines matching the following pattern
   Aae:7159:Aedes aegypti
   Afp:338618:Aquilegia formosa x Aquilegia pubescens
   Aga:7165:Anopheles gambiae

3) Update the path to append the species_name as mentioned in the README file 
   ftp://ftp.ncbi.nih.gov/repository/UniGene/Aedes_aegypti/

4) Download the seq.uniq file
   ftp://ftp.ncbi.nih.gov/repository/UniGene/Aedes_aegypti/Aae.seq.uniq.gz

=cut
sub _get_remote {
  my $self = shift;
  my $path = shift; # path is already checked as valid.
  my $readme = $self->get_ftp_files($self->uri, "README", $path);
  $self->log->debug('Downloaded README FTP file: '.join("\n",@$readme));
  my @readme_lines = read_file($$readme[0]) ;
  my @results;
  foreach my $readme_line (@readme_lines){
    chomp($readme_line);
    
    #Aae:7159:Aedes aegypti
    if(my ($species_code, $species_taxid, $species_name) = $readme_line =~ /(\w+)\:(\d+)\:(.*)/){
      $species_name =~ s/\s+/_/g;
      next unless $species_taxid eq '9606';
      my $uri = $self->uri . $species_name;
      my $result;
        
      $result = $self->get_ftp_files($uri, $self->file_pattern, $path);
      if(scalar(@$result) > 0){
        my $downloaded_file = $result->[0];
        my ($fname,$fpath,$fsuffix) = fileparse($downloaded_file);
        my $updated_fpath = $fpath . '/'. $species_taxid .'_'. $fname;
        move($downloaded_file, $updated_fpath);
        push(@results, $updated_fpath);
        $self->log->debug('Downloaded UniGene FTP file: '.$updated_fpath);
      }
    }
  }
   return \@results if (scalar @results > 0);
   Bio::EnsEMBL::Mongoose::NetException->throw("No files downloaded from UniGene source");
}

__PACKAGE__->meta->make_immutable;

1;
