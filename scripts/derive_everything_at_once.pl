# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Trial script to process TTL files into derived xrefs and happy results


use Modern::Perl;
use File::Spec;
use Bio::EnsEMBL::Mongoose::Serializer::RDF;
use Time::HiRes qw/gettimeofday tv_interval/;
use Bio::EnsEMBL::RDF::XrefReasoner;
use Bio::EnsEMBL::Registry;
use File::Slurper 'read_dir';
use IO::File;
use XrefScriptHelper;
use Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings;
use Bio::EnsEMBL::DBEntry;
use Bio::EnsEMBL::IdentityXref;

my $opts = XrefScriptHelper->new_with_options();

# Consult Ensembl staging DB for this release' list of valid stable IDs
Bio::EnsEMBL::Registry->load_registry_from_db( -host => $opts->ens_host, -port => $opts->ens_port, -user => $opts->ens_user, -pass => $opts->ens_pass, -db_version => $opts->ens_db_version, -NO_CACHE => 1);
my $db_entry_adaptor = Bio::EnsEMBL::Registry->get_adaptor($opts->species,'core','DBEntry');

my $namespace_mapper = Bio::EnsEMBL::RDF::EnsemblToIdentifierMappings->new($opts->config_file,$opts->config_schema);

my $debug_fh;
if ($opts->debug == 1) {
  printf "Debug is turned ON and going to %s\n",$opts->debug_file;
  $debug_fh = IO::File->new($opts->debug_file ,'w') || die "Unable to create debug output:".$opts->debug_file;
}

my $reasoner = Bio::EnsEMBL::RDF::XrefReasoner->new(keepalive => 0, memory => $opts->fuseki_heap, debug_fh => $debug_fh);

# PHASE 1, process the coordinate overlaps into default model

my $data_root = File::Spec->catfile($opts->ttl_path,$opts->species,'xref_rdf_dumps');
my $overlap_source = File::Spec->catfile($data_root,'coordinate_overlap','refseq_coordinate_overlap.ttl');
my $e_gene_model = File::Spec->catfile($data_root,'gene_model','ensembl.ttl');
my $refseq_gene_model = File::Spec->catfile($data_root,'gene_model','RefSeq.ttl');
my $checksum_source = File::Spec->catfile($data_root,'checksum','RefSeq_checksum.ttl');
my $checksum_uniprot_source = File::Spec->catfile($data_root,'checksum','Swissprot_checksum.ttl');
my $alignment_source = File::Spec->catfile($data_root,'alignment');

# Get all TTL files in data_root not in a subdirectory
my @loadables = read_dir($data_root);
@loadables = map { $data_root.'/'.$_ } grep { /.ttl/ } @loadables;
my $transitive_data = File::Spec->catfile($data_root,'transitive');
my @transitive = read_dir($transitive_data);
@transitive = map { $transitive_data.'/'.$_} @transitive;

my $start_time = [gettimeofday];
$reasoner->load_general_data($overlap_source,$e_gene_model,$refseq_gene_model,$checksum_source,$checksum_uniprot_source,@loadables);
$reasoner->load_alignments($alignment_source);
$reasoner->load_transitive_data(\@transitive);
my $done_time = tv_interval($start_time,[gettimeofday]);
print "Alignments, checksums, overlaps and gene model loaded\n";
print "Loaded all data in $done_time seconds\n";

# $reasoner->pretty_print_stats($reasoner->calculate_stats());
# print "Stats finished, now select transitive xrefs into a new graph\n";
$reasoner->nominate_transitive_xrefs();
print "Transitive xrefs supplemented with choices from coordinate matches, alignments and such.\n";

my $matches_fh = IO::File->new($opts->output_file,'w');

my %uri_to_enum = (
  Coordinate_overlap => 'COORDINATE_OVERLAP',
  Alignment => 'SEQUENCE_MATCH',
  Checksum => 'CHECKSUM',
  Direct => 'DEPENDENT'
);

my %uri_to_analysis_id = (
  Coordinate_overlap => 9238,
  Alignment => 9238,
  Checksum => 9240,
  Direct => 9239
);

# Difficult to get info_text right after the fact.
# my %uri_to_info_text = (
#   Coordinate_overlap => 'Generated via otherfeatures',
#   Direct => 'Generated via direct'
# );

# Cleanse existing xref table of undesirable xrefs. This means nearly everything except that which is not ours to delete.
delete_renewable_xrefs($opts);

my %failures;

foreach my $type (qw/Gene Transcript Translation/) {
  my $adaptor = Bio::EnsEMBL::Registry->get_adaptor($opts->species,'core',$type);
  my $features = $adaptor->fetch_all();
  while (my $feature = shift $features) {
    # Get a list of all IDs that are "the same thing" and are linked in the transitive graph
    my $matches = $reasoner->extract_transitive_xrefs_for_id($feature->stable_id);
    if ($opts->debug == 1) {
      printf $matches_fh "%s\t",$feature->stable_id;
    }
    my %source_cache = map { $_->{xref_source} => 1} @$matches;

    my @labels;
    foreach my $match (@$matches) {
      next if (
        $match->{xref_source} eq 'http://rdf.ebi.ac.uk/resource/ensembl/'
          || $match->{xref_source} eq 'http://rdf.ebi.ac.uk/resource/ensembl.transcript/'
          || $match->{xref_source} eq 'http://rdf.ebi.ac.uk/resource/ensembl.protein/'
        ); # We don't need to revisit any Ensembl ID. Sometimes Ensembl IDs are externally used so we have to check to the source too
      my $match_set = $reasoner->get_detail_of_uri($match->{uri});

      my $root_id = $match->{xref_label}; #Could also get this from $match_set
      my $root_source = $match_set->[0]->{source}; # Get source of original ID after the fact. It's not in the transitive graph
      print "Mapped transitive root $root_source on ID $root_id to " if ($opts->debug == 1);
      $root_source = $namespace_mapper->convert_uri_to_external_db_name($root_source);
      print "$root_source\n" if ($opts->debug == 1 && defined $root_source);
      if (! defined $root_source) {
        printf "Failed to resolve %s into external_db for id %s\n",$match_set->[0]->{source},$match_set->[0]->{id};
        $failures{$root_source}++;
        next;
      } else {
        printf "Storing direct xref %s:%s with label %s into Ensembl core DB\n",$match_set->[0]->{source},$match_set->[0]->{id},$match_set->[0]->{id};
      }

      # Insert as Direct Xref
      my $dbentry = Bio::EnsEMBL::DBEntry->new(
        -primary_id => $root_id,
        -dbname => $root_source,
        -display_id => $match_set->[0]->{display_label},
        -description => $match_set->[0]->{description},
        -info_type => 'DIRECT'
        );
      $db_entry_adaptor->store($dbentry,$feature->dbID,$type,1);
      # dbentry, Ensembl internal dbID, feature type, ignore external DB version
      print $matches_fh "$root_source:$root_id," if $opts->debug == 1;

      # Consider local ID for naming
      my $naming_priority = $namespace_mapper->get_priority($root_source);
      if (defined $naming_priority && defined $match_set->[0]->{display_label} ) {
        push @labels,[$dbentry,$naming_priority];
      }

    }

    # Now visit all the "dependent" xrefs attached to each of the the transitively linked xrefs
    foreach my $match (@$matches) {
      
      my $related_set = $reasoner->get_related_xrefs($match->{uri});
      # In principle we can attach the dependent xref to its master xref, but it's difficult
      
      foreach my $hit (@$related_set) {
        next if (
         $hit->{source} eq 'http://rdf.ebi.ac.uk/resource/ensembl/'
          || $hit->{source} eq 'http://rdf.ebi.ac.uk/resource/ensembl.transcript/'
          || $hit->{source} eq 'http://rdf.ebi.ac.uk/resource/ensembl.protein/'
        ); # No un-approved xrefs to Ensembl sources
        
        my $external_db_name = $namespace_mapper->convert_uri_to_external_db_name($hit->{source});
        if (!defined $external_db_name) { $failures{$hit->{source}}++ ; next } # Skip any sourceless xrefs
        
        # We don't want to re-discover the alignments from a source when we already have a winner selected
        # Don't store additional xrefs for any source which is already in the transitive set
        next if exists $source_cache{ $hit->{source} };
        
        printf "Mapped dependent xref %s on ID %s to %s\n",$hit->{source},$hit->{id},$external_db_name if ($opts->debug == 1);
        if ($opts->debug == 1) {
          printf $matches_fh ',%s:%s',$external_db_name,$hit->{id};
        }

        # Inspect link to determine xref type and store it.
        my $link_type = $hit->{type};
        $link_type =~ s|http://rdf.ebi.ac.uk/terms/ensembl/||;
        my $info_type = $uri_to_enum{$link_type};
        my $linked_dbentry;
        if ($info_type eq 'SEQUENCE_MATCH') {
          my $target_identity = $reasoner->get_target_identity($match->{uri},$hit->{uri});

          $linked_dbentry = Bio::EnsEMBL::IdentityXref->new(
            -primary_id => $hit->{id},
            -dbname => $external_db_name,
            -display_id => $hit->{display_label},
            -description => $hit->{description},
            -info_type => $info_type,

            -ensembl_identity => $hit->{score} * 100, # the alignment values
            -xref_identity => $target_identity * 100
          );
        } else {
          # Insert as a Dependent Xref
          $linked_dbentry = Bio::EnsEMBL::DBEntry->new(
            -primary_id => $hit->{id},
            -dbname => $external_db_name,
            -display_id => $hit->{display_label},
            -description => $hit->{description},
            -info_type => $info_type
          );
        }
        $db_entry_adaptor->store($linked_dbentry,$feature->dbID,$type,1);

        # Find a naming authority and apply synonyms
        my $naming_priority = $namespace_mapper->get_priority($external_db_name); # The priorities are actually available via query too, from source data
        if (defined $naming_priority && defined $hit->{label} ) {
          push @labels,[$linked_dbentry,$naming_priority];
        }
      }
      print $matches_fh ',' if $opts->debug == 1;
    }
    print $matches_fh "\n" if $opts->debug == 1;

    @labels = sort { $b->[1] <=> $a->[1]} @labels; # order desc by priority. Highest priority is the naming authority for this feature
    if (@labels > 0 && ($type eq 'Gene' || $type eq 'Transcript')) {
      my $dbentry = $labels[0]->[0];
      $feature->display_xref($dbentry);
      $adaptor->update($feature);
    }
  }
}

$matches_fh->close;
$debug_fh->close if $debug_fh;
print "The following xrefs were abandoned due to no source mapping to Ensembl:\n";
foreach my $failed_source (keys %failures) {
  printf "%s\t%i\n",$failed_source,$failures{$failed_source};
}

# This function will probably have to change for InnoDB schemas. They can do foreign key deletes unlike MyISAM
sub delete_renewable_xrefs {
  my $opts = shift;
  my $db_entry_adaptor =Bio::EnsEMBL::Registry->get_adaptor($opts->species,'core','DBEntry');
  my @do_not_delete;
  # Extend this list of external db_names to include anything we must not lose between release
  # i.e. anything from Havana/vega or genebuild, as well as LRG data
  for my $db_name (qw/KEGG_Enzyme MetaCyc Interpro CCDS Ens_Hs_gene Ens_Hs_transcript Ens_Hs_translation ENS_LRG_gene ENS_LRG_transcript LRG/) {
    my $id = $db_entry_adaptor->get_external_db_id($db_name,undef,1);
    push @do_not_delete,$id;
  }
  my $sth = $db_entry_adaptor->prepare(
    sprintf "
      DELETE xref,object_xref 
      FROM xref
      LEFT JOIN object_xref ON object_xref.xref_id = xref.xref_id 
      WHERE xref.external_db_id NOT IN (%s)",join(',',@do_not_delete)
    );
  $sth->execute();
  $sth = $db_entry_adaptor->prepare('DELETE FROM identity_xref');
  $sth->execute();
}

