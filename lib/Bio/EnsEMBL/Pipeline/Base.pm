=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Pipeline::Base

=head1 DESCRIPTION

A module for base methods used in more than one module

=over 8

=cut

package Bio::EnsEMBL::Pipeline::Base;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::DB;
use Bio::EnsEMBL::Versioning::Manager::Resources;
use Bio::EnsEMBL::Utils::Net qw/do_FTP/;
use Carp;
use Net::FTP;
use URI;
use File::Basename;

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;


=head2 get_ftp_file

  Example     :
  Description : Given a ftp resource, returns the corresponding file or files
  Returntype  : File
  Exceptions  : Undef if file cannot be found
  Caller      : internal
  Status      : Stable

=cut


sub get_ftp_file
{
  my $self = shift;
  my $resource = shift;
  my $filename = shift;

  my $url = $resource->value();
  my @urls = split("/", $url);
  my @files;
  my $download_name;
  my $result;
  if ($resource->multiple_files) {
    my $uri = URI->new($url);
    my $files = $self->ls_ftp_dir($uri);
    foreach my $file (@$files) {
      if ($file =~ /$urls[-1]/) {
        if (defined $filename) {
          $download_name = $filename . '/' . $file;
        }
        $url = 'ftp://' . $uri->host() . dirname($uri->path) . '/' . $file;
        eval { $result = do_FTP($url, undef, undef, $download_name); };
        if ($@) {
          carp($@);
          $result = undef;
        }
        push @files, $result;
      }
    }
  } else {
    if (defined $filename) {
      $filename = $filename . '/' . $urls[-1];
    }
    eval { $result = do_FTP($url, undef, undef, $filename); };
    if ($@) {
      carp($@);
      return;
    }
    return $result;
  }
  return \@files;
}

sub ls_ftp_dir
{
  my $self = shift;
  my $uri = shift;

  my $ftp = Net::FTP->new($uri->host());
  if (!$ftp->login('anonymous', '-anonymous@')) {
    croak("Cannot log in on ftp host");
  }
  if (!$ftp->cwd(dirname($uri->path()))) {
    croak("Cannot change directory");
  }
  my @files = @{ $ftp->ls() };
  return \@files;
}

1;
