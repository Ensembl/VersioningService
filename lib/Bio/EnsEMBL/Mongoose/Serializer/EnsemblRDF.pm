# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Pulls the gene model out of Ensembl and turns it into a basic graph

package Bio::EnsEMBL::Mongoose::Serializer::EnsemblRDF;

use Moose;
use IO::File;
use Config::General;
use Bio::EnsEMBL::Registry;

extends 'Bio::EnsEMBL::Mongoose::Serializer::RDFLib';

has species =>  (is => 'rw', isa=>'Str',required => 1);

has config_file => (
  isa => 'Str',
  is => 'ro',
  default => sub {
    my $path = "$ENV{MONGOOSE}/conf/databases.conf";
    return $path;
  },
);

has config => (
  isa => 'HashRef',
  is => 'ro',
  required => 1,
  default => sub {
    my $self = shift;
    my $conf = Config::General->new($self->config_file);
    my %opts = $conf->getall();
    return \%opts;
  },
);

# modify to support two ensembl DBs...
before 'print_record' => sub {
  my $self = shift;
  Bio::EnsEMBL::Registry->load_registry_from_db(
    -host => $self->config->{ensembl_host},
    -user => $self->config->{ensembl_user},
    -port => $self->config->{ensembl_port},
    -pass => $self->config->{ensembl_pass},
    -db_version => $self->config->{ensembl_version},
    -no_cache => 1,
  );
};

sub print_record {
  my $self = shift;
  my $fh = $self->handle;
  my $ga = Bio::EnsEMBL::Registry->get_adaptor($self->species,'core','Gene');
  my $genes = $ga->fetch_all;
  while (my $gene = shift @{$genes}) {
    my $transcripts = $gene->get_all_Transcripts;
    while (my $transcript = shift @{$transcripts}) {
      print $fh $self->triple( $self->u($self->prefix('ensembl').$transcript->stable_id),
                        $self->u($self->prefix('obo').'SO_transcribed_from'),
                        $self->u($self->prefix('ensembl').$gene->stable_id));
      my $translation = $transcript->translation;
      if ($translation) {
        print $fh $self->triple( $self->u($self->prefix('ensembl').$transcript->stable_id),
                          $self->u($self->prefix('obo').'SO_translates_to'),
                          $self->u($self->prefix('ensembl').$translation->stable_id));  
      }
    }
  }
}



1;