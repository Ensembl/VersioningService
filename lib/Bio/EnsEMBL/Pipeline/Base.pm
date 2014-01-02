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
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Net qw/do_FTP/;
use Carp;
use POSIX qw/strftime/;

use base qw/Bio::EnsEMBL::Hive::Process/;


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

  my $url = $resource->value();
  my $file = do_FTP($url);

  return $file;
}

1;
