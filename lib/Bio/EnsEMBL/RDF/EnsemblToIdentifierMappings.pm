=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

    EnsemblToIdentifierMappings - Module to help map Ensembl Xrefs to Identifiers.org namespaces

=head1 SYNOPSIS
  my $mapper = Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings->new($config_file);
  print $mapper->LOD_uri('uniprot');
  # http://purl.uniprot.org/uniprot
  print $mapper->identifier_org_translation('uniprot')
  # http://identifiers.org/uniprot

=head1 DESCRIPTION

  This module takes Ensembl internal names for things and converts them into identifiers.org URIs,
  or directly to the specific namespace of the host organisation for the data type if we know it.
  It requires a xref_LOD_mapping.json file on instantiation

=cut

package Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings;

use strict;
use JSON qw/decode_json/;
use IO::File;

sub new {
  my ($class,$xref_mapping_file) = @_;
  local $/;
  my $fh = IO::File->new($xref_mapping_file,'r');
  unless ($fh) { die "Disaster! No xref config JSON file found $@"}
  my $json = <$fh>;
  my $doc = decode_json($json);
  my %xref_mapping;
  map { $xref_mapping{ $_->{db_name} } = $_ } @{ $doc->{mappings} };
  bless({ xref_mapping => \%xref_mapping },$class);
}
# For a given Ensembl ExternalDB name, gives a hash containing any of:
# db_name - Ensembl internal name for an external DB
# example_id
# "standard abbreviation" id_namespace, combines with "http://identifiers.org/" to give a
# suitable URI for SPARQL queries.
# canonical_LOD - or base URI LOD = Linked Open Data
# URI_type - the class of things a URI belongs to for this source
# ignore (boolean)
# EDAM_type
# EDAM_term
# regex - used to transform a textual ID into a URI
sub get_mapping {
  my $self = shift;
  my $e_name = shift;
  my $mappings = $self->{xref_mapping};
  if (exists $mappings->{$e_name}) {
    return $mappings->{$e_name};
  } else {
    return;
  }
}

# Returns an identifiers.org URI for a given ensembl internal name
sub identifier_org_translation {
  my $self = shift;
  my $e_name = shift;
  return unless $e_name;
  my $mappings = $self->{xref_mapping};
  if (exists $mappings->{$e_name} && $mappings->{$e_name} && exists $mappings->{$e_name}->{id_namespace}) {
    my $id_url = $mappings->{$e_name}->{id_namespace};
    return "http://identifiers.org/".$id_url."/";
  } else {
    warn "No identifiers.org name for $e_name"; 
    return; 
  }
}

# Returns the abbreviated form of the identifiers.org namespace
sub identifier_org_short {
  my $self = shift;
  my $e_name = shift;
  my $mappings = $self->{xref_mapping};
  if (exists $mappings->{$e_name}) {
    my $id = $mappings->{$e_name}->{id_namespace};
    return $id;
  } else {
    return;
  }
}

# Returns Linked Open Data URIs instead of identifiers.org ones. This is useful for resources that
# have well defined URIs that we can formulate locallym hence allowing federation/merging without
# querying identifiers.org to find equivalence.
sub LOD_uri {
  my $self = shift;
  my $e_name = shift;
  my $mappings = $self->{xref_mapping};
  my $lod;
  if (exists $mappings->{$e_name}->{canonical_LOD}) {
    $lod = $mappings->{$e_name}->{canonical_LOD};
  } else {
    return;
  }
  return $lod;
}

1;