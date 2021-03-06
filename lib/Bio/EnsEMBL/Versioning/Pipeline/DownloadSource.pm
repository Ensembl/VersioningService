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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Versioning::Pipeline::DownloadSource

=head1 DESCRIPTION

A module which downloads a given source and saves it as a file


=cut

package Bio::EnsEMBL::Versioning::Pipeline::DownloadSource;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Broker;
use Try::Tiny;
use Log::Log4perl;
Log::Log4perl::init("$ENV{MONGOOSE}/conf/logger.conf");

use parent qw/Bio::EnsEMBL::Versioning::Pipeline::Base/;

sub run {
  my ($self) = @_;
  my $latest_version = $self->param('version');
  my $source_name = $self->param('source_name');
  my $broker = $self->configure_broker_from_pipeline();
  my $source = $broker->get_source($source_name);
  my $downloader = $broker->get_module($broker->get_downloader($source_name))->new;
  my $result;
  my $temp_location = $broker->temp_location;
  try {
    $result = $downloader->download_to($temp_location);
  } catch {
    my $input_id = {
      error => "Files could not be downloaded for ".$source_name.". Exception: ".$_->message,
      source_name => $source_name
    };
    $self->warning(sprintf 'Download failed for %s for %s', $source_name, 'update_pipeline');
    return;
  };
  $broker->finalise_download($source,$latest_version,$temp_location);

  $self->warning("Downloaded resource $source_name to be forked into parsing jobs");
  my $message = { source_name => $source_name , version => $latest_version };
  $self->dataflow_output_id($message, 2);
  
  return;

}



1;
