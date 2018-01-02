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

EnsemblToIdentifierMappings - Module to help map Ensembl Xrefs to Identifiers.org namespaces

=head1 SYNOPSIS
  my $mapper = Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings->new($config_file);
  print $mapper->LOD_uri('uniprot');
  # http://purl.uniprot.org/uniprot
  print $mapper->identifier_org_translation('uniprot')
  # http://identifiers.org/uniprot

  # Optionally attempts to validate the config file if given a JSON schema file

=head1 DESCRIPTION

  This module takes Ensembl internal names for things and converts them into identifiers.org URIs,
  or directly to the specific namespace of the host organisation for the data type if we know it.
  It requires a xref_LOD_mapping.json file on instantiation

=cut

package Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings;

use strict;
use JSON qw/decode_json/;
use IO::File;
use Carp qw/confess/;
use URI::Escape;
use URI::Split qw(uri_split uri_join);

sub new {
  my ($class,$xref_mapping_file,$schema_file) = @_;
  local $/;
  my $fh = IO::File->new($xref_mapping_file,'r');
  unless ($fh) { die "Disaster! No xref config JSON file found $@"}
  my $json = <$fh>;
  my $doc = decode_json($json);

  if ($schema_file) {
    require JSON::Validator;
    my $schema_fh = IO::File->new($schema_file,'r') || confess ("Cannot read schema file $schema_file");
    my $schema = <$schema_fh>;
    my $validator = JSON::Validator->new();
    $validator->schema(decode_json($schema));
    my @result = $validator->validate($doc);
    if (@result) {
      # This only works because JSON::Schema has some strange overloaded functions - intended usage pattern
      confess("Validation error on JSON config file $xref_mapping_file with schema $schema_file.\n".join("\n",map { $_->message .':'.$_->path } @result));
    }
  }

  my %xref_mapping;
  my %reverse_mapping; # reverse mapping may be unused
  map { $xref_mapping{ lc $_->{db_name} } = $_ } @{ $doc->{mappings} };
  my $root = 'http://identifiers.org/';
  for my $record (@{ $doc->{mappings}}) {
    if (exists $record->{ensembl_db_name}) {
      $reverse_mapping{ $root . $record->{id_namespace} .'/' } = $record->{ensembl_db_name};
      $reverse_mapping{ $record->{canonical_LOD} } = $record->{ensembl_db_name} if exists $record->{canonical_LOD};
    }
  }
  
  bless({ xref_mapping => \%xref_mapping, reverse_mapping => \%reverse_mapping },$class);
}
# For a given Ensembl ExternalDB name, gives a hash containing any of:
# db_name - Ensembl "xref" internal name for an external DB
# ensembl_db_name - external_db_name found in the core schema external_db table
# example_id
# "standard abbreviation" id_namespace, combines with "http://identifiers.org/" to give a
# suitable URI for SPARQL queries.
# canonical_LOD - or base URI LOD = Linked Open Data
# URI_type - the class of things a URI belongs to for this source
# ignore (boolean)
# EDAM_type
# EDAM_term
# regex - used to transform a textual ID into a URI
# bidirectional (boolean) - expresses whether links should be considered symmetric or not.
# Enables us to have xrefs to gene trees without inferring links to all genes in that tree
sub get_mapping {
  my $self = shift;
  my $e_name = shift;
  $e_name = lc($e_name);
  my $mappings = $self->{xref_mapping};
  if (exists $mappings->{$e_name}) {
    return $mappings->{$e_name};
  } else {
    return;
  }
}

# Returns an identifiers.org URI for a given ensembl internal name
my %seen;
sub identifier_org_translation {
  my $self = shift;
  my $e_name = shift;
  return unless $e_name;
  $e_name = lc($e_name);
  my $mappings = $self->{xref_mapping};
  if (exists $mappings->{$e_name} && $mappings->{$e_name} && exists $mappings->{$e_name}->{id_namespace}) {
    my $id_url = $mappings->{$e_name}->{id_namespace};
    return "http://identifiers.org/".$id_url."/";
  } elsif (! exists $seen{$e_name}){
    warn "No identifiers.org name for $e_name"; 
    $seen{$e_name} = 1;
  } else {
    $seen{$e_name}++;
  }
  return;
}

# Returns the abbreviated form of the identifiers.org namespace
sub identifier_org_short {
  my $self = shift;
  my $e_name = shift;
  $e_name = lc($e_name);
  my $mappings = $self->{xref_mapping};
  if (exists $mappings->{$e_name}) {
    my $id = $mappings->{$e_name}->{id_namespace};
    return $id;
  } else {
    return;
  }
}

# Returns Linked Open Data URIs instead of identifiers.org ones. This is useful for resources that
# have well defined URIs that we can formulate locally hence allowing federation/merging without
# querying identifiers.org to find equivalence.
sub LOD_uri {
  my $self = shift;
  my $e_name = shift;
  $e_name = lc($e_name);
  my $mappings = $self->{xref_mapping};
  my $lod;
  if (exists $mappings->{$e_name}->{canonical_LOD}) {
    $lod = $mappings->{$e_name}->{canonical_LOD};
  } else {
    return;
  }
  return $lod;
}

# Requires $source argument to be an Ensembl name for an external source
sub identifier {
  my $self = shift;
  my $source = shift;
  Bio::EnsEMBL::Mongoose::UsageException->throw('No argument to RDFLib::identifier()') unless defined $source;
  my $id_org = $self->LOD_uri($source);
  if ($id_org) {
    return $id_org;
  } else {
    $id_org = $self->identifier_org_translation($source);
    unless ($id_org) { $id_org = 'http://rdf.ebi.ac.uk/resource/ensembl/xref/'.uri_escape($source).'/'}
    return $id_org;
  }
}


# Return all entries available with either a LOD link or a more generic one
sub get_all_name_mapping {
  my $self = shift;
  my %mappings;
  my $map = $self->{xref_mapping};
  foreach my $short_name(keys %$map) {
    $mappings{$short_name} = $self->identifier($short_name);
  }
  return \%mappings;
}

# Given an source name and a target name (from Ensembl or xref sources), determines if an xref should be bidirectional/transitive
# Used by the Xref RDF code to generate reversible links for ID equivalence, and one-way links for many-to-one IDs

# Returns [boolean,boolean], corresponding to outbound link true/false and return link true/false
sub allowed_xrefs {
  my $self =shift;
  my $source = shift;
  my $target_source = shift;
  my $source_type = $self->get_feature_type($source);
  my $target_type = $self->get_feature_type($target_source);
  return 1 if $source_type eq $target_type and $source_type ne 'annotation';
  return 0;
}


# sub is_bidirectional {
#   my $self = shift;
#   my $source = shift;
#   $source = lc $source;
#   my $map = $self->{xref_mapping};
#   if (exists $map->{$source} && defined $map->{$source}->{feature_type}) {
#     my $type = $map->{$source}->{feature_type};
#     return 1 if $type eq 'gene' or $type eq 'transcript' or $type eq 'translation';
#     return;
#   }
#   return;
# }

# Possible values for feature type = gene, transcript, translation, annotation
sub get_feature_type {
  my $self = shift;
  my $source = shift;
  $source = lc $source;
  my $map = $self->{xref_mapping};
  if (exists $map->{$source} && defined $map->{$source}->{feature_type}) {
    return $map->{$source}->{feature_type};
  }
    return;
}

# Hackery required to be able to map IDs into our antique external_db list
# A dcterms:source tag will differentiate between them, since we cannot do it from ID alone most of the time.
# With RefSeq IDs we can, so we shoehorn them by ID here.
sub generate_source_uri {
  my $self = shift;
  my $source = shift;
  my $accession = shift;
  my $source_uri;
  my $general_source_uri;
  # $source = uri_escape($source);
  my $mappings = $self->{xref_mapping};
  
  # Commence refseq-themed hack
  if ($source =~ /refseq/i) {
    $source_uri = 'http://rdf.ebi.ac.uk/resource/ensembl/source/';
    $general_source_uri = $self->identifier('refseq');
    unless ($accession) {
      confess "Unable to generate a source URI for $source without an accession to disambiguate" ;
    }
    # For RefSeq we cannot always guarantee that we will know which subset an ID belongs to so we must inspect the prefix
    if ($accession =~ /^NM/) {
      $source_uri .= $mappings->{refseq_mrna}->{ensembl_db_name};
    } elsif ($accession =~ /^XM/) {
      $source_uri .= $mappings->{refseq_mrna_predicted}->{ensembl_db_name};
    } elsif ($accession =~ /^NR/) {
      $source_uri .= $mappings->{refseq_ncrna}->{ensembl_db_name};
    } elsif ($accession =~ /^XR/) {
      $source_uri .= $mappings->{refseq_ncrna_predicted}->{ensembl_db_name};
    } elsif ($accession =~ /^(NP|YP)/) {
      $source_uri .= $mappings->{refseq_peptide}->{ensembl_db_name};
    } elsif ($accession =~ /^XP/) {
      $source_uri .= $mappings->{refseq_peptide_predicted}->{ensembl_db_name};
    } else {
      $source_uri = $self->identifier($source); # Beaten - resort to blind guesswork  
    }
    $source_uri .= '/';
    # most other sources can be handled automatically
  } elsif (exists $mappings->{lc $source} && exists $mappings->{lc $source}->{ensembl_db_name}) {
    $source_uri = 'http://rdf.ebi.ac.uk/resource/ensembl/source/'.uri_escape( $mappings->{lc $source}->{ensembl_db_name} ).'/';
    $general_source_uri = $self->identifier($source);
    # This can be removed when external_db no longer dictates what we call sources in Ensembl
  } else {
    $source_uri = $self->identifier($source);
    $general_source_uri = $source_uri;
  }
  return $source_uri,$general_source_uri;
}



sub convert_uri_to_external_db_name {
  my $self = shift;
  my $uri = shift;

  # print "Received $uri\n";
  $uri =~ s/<|>//g; # Just in case an RDF-style URI has escaped uncleaned
  if ($uri =~ m{http://rdf.ebi.ac.uk/resource/ensembl/source/(.+)}) {
    my $external_db_name = $1;
    $external_db_name =~ s/\/$//; # Trim any trailing slashes
    return uri_unescape($external_db_name);
  } else {
    # Unpack what we can from a regular identifiers.org type URL
    my ($scheme, $auth, $path, $query, $frag) = uri_split($uri);
    # $auth is "authority", URL

    my $id_free_path = $path;
    $id_free_path =~ s/([\w:]+)$//;
    my ($id) = $1; # Don't return the ID unless it proves necessary in future
    my $namespace = uri_join($scheme,$auth,$id_free_path,undef,undef);
    my $reverse_mapping = $self->{reverse_mapping};
    if (exists $reverse_mapping->{$namespace}) {
      my $external_db_name = $reverse_mapping->{$namespace};
      return $external_db_name;
    } else {
      warn "URI $namespace not recognised as mappable to external db names";
      return;
    }
    
  }


}

# Given a source name, return the priority score if there is one
sub get_priority {
  my $self = shift;
  my $source = shift;
  my $mappings = $self->{xref_mapping};
  if (exists $mappings->{lc $source} ) {
    if (exists $mappings->{lc $source}->{priority}) {
      return $mappings->{lc $source}->{priority};
    }
  }
  return;
}



1;
