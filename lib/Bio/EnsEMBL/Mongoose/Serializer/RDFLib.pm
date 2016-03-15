# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This is a thin wrapper around the non-Moose RDF libraries that are also used by the unMoosey RDF dumping pipeline

package Bio::EnsEMBL::Mongoose::Serializer::RDFLib;

use Moose;
use namespace::autoclean;

use Bio::EnsEMBL::RDF::RDFlib;
use Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings;
use Bio::EnsEMBL::Mongoose::UsageException;
use Config::General;
# lookup for IDs that classify annotation, rather than assert identity between genomic resources
# If listed here, the relationship between two IDs should be unidirectional to prevent logical armageddon
has unidirection_sources => (
  traits => ['Hash'],
  is => 'ro',
  isa => 'HashRef',
  default => sub {{
    go => 1,
    interpro => 1,
    rfam => 1,
    treefam => 1,
    mim_morbid => 1
  }},
  handles => { 
    is_unidirectional => 'exists'
  }
);

has identifier_mapping => (is => 'ro', isa => 'Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings', builder => '_load_mapper');
has config_file => (is => 'ro', isa =>'Str', required => 1);
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
    Bio::EnsEMBL::Mongoose::UsageException->throw('Identifiers.org mappings require config file '.$self->config_file.' to link to a JSON mappings file with key LOD_location');
  }
  return Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings->new($path_to_lod_file);
}

sub new_xref {
  my $self = shift;
  $self->another_xref;
  return $self->prefix('ensembl').'xref/'.$self->xref_id();
}


# Requires $source argument to be an Ensembl name for an external source
sub identifier {
  my $self = shift;
  my $source = shift;
  Bio::EnsEMBL::Mongoose::UsageException->throw('No argument to RDFLib::identifier()') unless defined $source;
  my $id_org = $self->identifier_mapping->LOD_uri($source);
  if ($id_org) {
    return $id_org;
  } else {
    return $self->identifier_mapping->identifier_org_translation($source);
  }
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