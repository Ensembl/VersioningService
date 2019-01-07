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

# This is a thin wrapper around the non-Moose RDF libraries that are also used by the unMoosey RDF dumping pipeline

package Bio::EnsEMBL::Mongoose::Serializer::RDFLib;

use Moose;
use namespace::autoclean;

use Bio::EnsEMBL::RDF::RDFlib;
use Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings;
use Bio::EnsEMBL::Mongoose::UsageException;
use Config::General;
use URI::Escape;

has identifier_mapping => (is => 'ro', isa => 'Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings', builder => '_load_mapper');
has config_file => (is => 'rw', isa =>'Str');
has config => (
    isa => 'HashRef',
    is => 'rw',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $conf = Config::General->new($self->config_file);
        my %opts = $conf->getall();
        return \%opts;
    },
);

has xref_id => (
  is => 'rw',
  isa => 'Num',
  traits => ['Counter'], 
  default => 0, 
  handles => {
    another_xref => 'inc',
  });

with 'MooseX::Log::Log4perl';

sub _load_mapper {
  my $self = shift;
  my $path_to_lod_file = $self->config->{LOD_location};
  unless (defined $path_to_lod_file) { 
    $self->log->debug("Missing LOD location in config: ".$self->config);
    Bio::EnsEMBL::Mongoose::UsageException->throw('Identifiers.org mappings require config or config file '.$self->config_file.' to link to a JSON mappings file with key LOD_location');
  }
  return Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings->new($path_to_lod_file);
}

sub new_xref {
  my $self = shift;
  my $source = shift;
  my $target = shift;
  my $label = shift; # Additional string to prevent xrefs of different types sharing the same xref ID
  $self->another_xref;
  my $xref_uri = $self->prefix('ensembl').'xref/connection/'.uri_escape($source).'/'.uri_escape($target).'/';
  $xref_uri .= $label.'/' if $label;
  $xref_uri .= $self->xref_id();
  return $xref_uri;
}

# Delegate URI generating to the mapping object
sub identifier { 
  my $self = shift;
  my $source = shift;
  return $self->identifier_mapping->identifier($source);
}
# Same here
sub generate_source_uri {
  my $self = shift;
  my $source = shift;
  my $accession = shift;
  return $self->identifier_mapping->generate_source_uri($source,$accession);
}


# Bunch of accessors for subroutines provided by non-object-based library 
sub prefix {
  shift;
  return Bio::EnsEMBL::RDF::RDFlib::prefix(@_);
}

sub u {
  shift;
  return Bio::EnsEMBL::RDF::RDFlib::u(@_);
}

sub triple {
  shift;
  return Bio::EnsEMBL::RDF::RDFlib::triple(@_);
}

sub escape {
  shift;
  return Bio::EnsEMBL::RDF::RDFlib::escape(@_);
}

sub clean_for_uri {
  shift;
  return Bio::EnsEMBL::RDF::RDFlib::clean_for_uri(@_);
}

sub taxon_triple {
  shift;
  return Bio::EnsEMBL::RDF::RDFlib::taxon_triple(@_);
}

sub namespaces {
  shift;
  return Bio::EnsEMBL::RDF::RDFlib::namespaces(@_);
}

sub compatible_name_spaces {
  shift;
  return Bio::EnsEMBL::RDF::RDFlib::compatible_name_spaces(@_);
}

sub new_bnode {
  shift;
  return Bio::EnsEMBL::RDF::RDFlib::new_bnode(@_);
}

__PACKAGE__->meta->make_immutable;

1;
