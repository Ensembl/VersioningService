=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Versioning::Pipeline::Downloader::HGNC

=head1 DESCRIPTION

A module for HGNC downloads. Original method:

wget=>http://www.genenames.org/cgi-bin/download
?title=HGNC+output+data&hgnc_dbtag=on&col=gd_hgnc_id&
col=gd_status&col=gd_ccds_ids&status=Approved&status_opt=2&level=pri&=on&where=&order_by=gd_app_sym_sort&limit=&
format=text&submit=submit&.cgifields=&.cgifields=level&.cgifields=chr&.cgifields=status&.cgifields=hgnc_dbtag,host=>ens-livemirror,dbname=>ccds_human_77

This data is now available from a REST endpoint based on Solr.

=cut

package Bio::EnsEMBL::Versioning::Pipeline::Downloader::HGNC;

use Moose;

extends 'Bio::EnsEMBL::Versioning::Pipeline::RESTDownloader';

sub BUILD {
  my $self = shift;
  $self->host('http://rest.genenames.org/');
  $self->remote_path('fetch/status/Approved');
  $self->file_name('hgnc');
  $self->file_pattern('');
  $self->accepts('application/json');
}


# HGNC continually updates its data, no releases. Therefore the version is a timestamp of now
sub get_version
{
  my $self = shift;
  return $self->timestamp;
}

__PACKAGE__->meta->make_immutable;

1;
