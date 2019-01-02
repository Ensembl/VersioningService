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

package Bio::EnsEMBL::Versioning::CoordinateMapper;

use Moose;
use Bio::EnsEMBL::Mapper::RangeRegistry;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use File::Temp qw/ tempfile tempdir /;
use Method::Signatures;
use Bio::EnsEMBL::Mongoose::UsageException;

=head2 create_index_from_database

  Arg[1]     : DBAdaptor (otherfeatures)
  Arg[2]     : analysis name (eg: refSeq_import)
  Arg[3]     : species name (eg: homo_sapiens)
  Example    : $mapper->create_index_from_database(species => $species, dba => $other_dba, analysis_name => "refseq_import");
  Description: Creates lucy index records from otherfeatures database in a temporary folder
  Returntype : String - Path of index folder

=cut

method create_index_from_database (Object :$dba, Str :$analysis_name, Str :$species) {

  # Use taxonomizer to convert name to taxid (homo_sapiens to 9606)
  my $taxonomizer = Bio::EnsEMBL::Mongoose::Taxonomizer->new();
  my $species_id = $taxonomizer->fetch_taxon_id_by_name($species);
  Bio::EnsEMBL::Mongoose::UsageException->throw("Species $species did not resolve to a taxonomy") unless defined $species_id;
  
  my $sa = $dba->get_SliceAdaptor();
  Bio::EnsEMBL::Mongoose::UsageException->throw('Unable to fetch an Ensembl Slice Adaptor from proferred database adaptor') unless defined $sa;
  my $chromosomes = $sa->fetch_all('chromosome', undef, 1);
  
  my $index_folder = tempdir( CLEANUP => 1 );
  my $doc_store = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new( index => $index_folder);
 
  my $logic_name;

  # Fetch analysis object for refseq
  my $aa_of = $dba->get_AnalysisAdaptor();

  foreach my $ana(@{ $aa_of->fetch_all() }) {
    if ($ana->logic_name =~ /$analysis_name/) {
      $logic_name = $ana->logic_name;
    }
  }
  ## Not all species have refseq_import data, skip if not found
  if (!defined $logic_name) {
    print STDERR "No data found for $analysis_name, skipping import\n";
    return;
  }

  
  foreach my $chromosome (@{$chromosomes}) {
    my $chr_name = $chromosome->seq_region_name();
    my $genes = $chromosome->get_all_Genes($logic_name, undef, 1);
    
     while (my $gene = shift @$genes) {
      my $transcripts = $gene->get_all_Transcripts();
      my $strand = $gene->strand();
      
      # Create an  index of all ensembl Transcript as lucy Records
      foreach my $transcript (sort { $a->start() <=> $b->start() } @$transcripts) {
        if (!$transcript->stable_id || $transcript->stable_id !~ /^(NR|XR|NM|NP|XM)/) {next} # filter out anything which doesn't look like a RefSeq transcript
        my $exons = $transcript->get_all_Exons();
        $self->store_as_record($species_id, $chr_name, $strand, $transcript, $exons, $doc_store );
      }#end foreach

     }#end while

  }#end foreach chr
  $doc_store->commit;
  return $index_folder;
} #end sub

# store the ensembl transcript object as Mongoose Peristance Record
sub store_as_record{
  my $self = shift;
  my ($species_id, $chr_name, $strand, $transcript, $exons, $doc_store ) = @_;
  
  my $transcript_start = sprintf("%018d", $transcript->start());
  my $transcript_end = sprintf("%018d", $transcript->end());
  
  my @exon_starts;
  my @exon_ends;
  foreach my $exon (@$exons) {
   my $start = $exon->seq_region_start();
   my $end = $exon->seq_region_end();
   push(@exon_starts, $start);
   push(@exon_ends, $end);
  }

  my $record = Bio::EnsEMBL::Mongoose::Persistence::Record->new('id'=>$transcript->stable_id(), 'start'=>$transcript_start, 'end'=>$transcript_end);
  $record->taxon_id($species_id) if $species_id;

  $record->entry_name($transcript->stable_id());
  $record->display_label($transcript->stable_id());
  
  $record->chromosome($chr_name);
  $record->strand($strand);
  $record->transcript_start($transcript_start);
  $record->transcript_end($transcript_end);
  
  if($transcript->translation){
    my $cds_start         = $transcript->coding_region_start();
    my $cds_end           = $transcript->coding_region_end();
    $record->cds_start($cds_start) if $cds_start;
    $record->cds_end($cds_end) if $cds_end;
  }

  $record->exon_starts(\@exon_starts);
  $record->exon_ends(\@exon_ends);
  
  $doc_store->store_record($record);

}


=head2 calculate_overlap_score

  Arg [1]    : index_location (the source data index  eg: refseq or ucsc), 
  Arg [2]    : species name
  Arg [3]    : core_dba (Ensembl DBAdaptor to a corelike database), 
  Arg [4]    : other_dba (Ensembl DBAdaptor to an otherfeatures database)
  Arg [5]    : rdf_writer (Serialiser::RDF)
  Arg [6]    : source (Name of external source to overlap against)
  Example    : $mapper->calculate_overlap_score(index_location => $temp_index_folder , species => $species, 
  	                                             core_dba => $core_dba, other_dba => $other_dba,
  	                                             rdf_writer => $rdf_writer , source => "refseq");
  Description: Calculates the overlap score between the ensemble transcripts and the other data source transcripts (refseq or ucsc)
  
  For each Ensembl transcript:
    1. Register all Ensembl exons in a RangeRegistry.

    2. Find all transcripts in the external database that are within the range of this Ensembl transcript

   For each of those external transcripts:
    3. Calculate the overlap of the exons of the external transcript with the Ensembl exons using the
       overlap_size() method in the RangeRegistry.

    4. Register the external exons in their own RangeRegistry.

    5. Calculate the overlap of the Ensembl exons with the external exons

    6. Calculate the match score.

    7. Decide whether or not to keep the match.
  Returntype : None

=cut


method calculate_overlap_score (ArrayRef :$index_location, Str :$species, Object :$core_dba, Object :$other_dba, :$rdf_writer, :$source) {
  
  my $taxonomizer = Bio::EnsEMBL::Mongoose::Taxonomizer->new();
  my $species_id = $taxonomizer->fetch_taxon_id_by_name($species);

  Bio::EnsEMBL::Mongoose::UsageException->throw("No species taxonomy ID for $species") unless $species;
  foreach my $path (@$index_location) {
    Bio::EnsEMBL::Mongoose::UsageException->throw("Index at $path does not seem to be there") unless defined $path and -e $path;
  }
  
  my $lucy_query = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => { index_location => $index_location });
  
  my $sa = $core_dba->get_SliceAdaptor();
  my $chromosomes_ens = $sa->fetch_all('chromosome', undef, 1);
  
  my %all_transcript_result;
  my %all_tl_transcript_result;
  my %all_mapping_result;
  # get all chromosomes from ensembl core db and iterate through them
  foreach my $chromosome_ens (@{$chromosomes_ens}) {
    my $chr_name = $chromosome_ens->seq_region_name();
    my $genes_ens = $chromosome_ens->get_all_Genes(undef, 'core', 1);
    
     foreach my $gene_ens (@{$genes_ens}) {
       my $transcripts_ens = $gene_ens->get_all_Transcripts();
      
      # register all Ensembl exons and translateable exons in a RangeRegistry separately
       foreach my $transcript_ens (sort { $a->start() <=> $b->start() } @$transcripts_ens) {

         my %transcript_result;
         my %tl_transcript_result;

         my $exons_ens = $transcript_ens->get_all_Exons();
         my $tl_exons_ens = $transcript_ens->get_all_translateable_Exons();
        
         my $ensembl_exon_rr = Bio::EnsEMBL::Mapper::RangeRegistry->new();
         my $ensembl_translateable_exon_rr = Bio::EnsEMBL::Mapper::RangeRegistry->new();
        
         # register ensembl exons
         foreach my $exon_ens (@$exons_ens) {
           my $start_ens = $exon_ens->seq_region_start();
           my $end_ens = $exon_ens->seq_region_end();
           $ensembl_exon_rr->check_and_register( 'exon', $start_ens, $end_ens );
         }

         # register ensembl translateable exons
         foreach my $tl_exon_ens (@$tl_exons_ens) {
           my $tl_start_ens = $tl_exon_ens->seq_region_start();
           my $tl_end_ens = $tl_exon_ens->seq_region_end();
           $ensembl_translateable_exon_rr->check_and_register( 'exon', $tl_start_ens, $tl_end_ens );
         }

          # pad the start and end as fixed width strings to enable sorting and searching with lucy (131555 to 000000000000131555)
          my $transcript_start = sprintf("%018d", $transcript_ens->start());
          my $transcript_end = sprintf("%018d", $transcript_ens->end());
        
          # fetch hits from otherdata source in lucy index (refseq or ucsc) that overlaps ensembl transcript start and end positions
          my $region_overlap_hits = $lucy_query->fetch_region_overlaps($species_id, $chr_name, $gene_ens->strand, $transcript_start, $transcript_end);
         
          my $id;
          foreach my $hit (@$region_overlap_hits){

            my $score = $self->calculate_score($hit,$ensembl_exon_rr,$exons_ens);
            my $tl_score = $self->calculate_score($hit,$ensembl_translateable_exon_rr,$tl_exons_ens,1);
            # store the score in hash with stable_id as key
            $id = $hit->{id};
            $transcript_result{$id} = $score;
            $tl_transcript_result{$id} = $tl_score;

            if($score > 0.75){
              $all_transcript_result{$id}{$transcript_ens->stable_id} = $score;
            }
            if($tl_score > 0.75){
              $all_tl_transcript_result{$id}{$transcript_ens->stable_id} = $tl_score;
              $all_transcript_result{$id}{$transcript_ens->stable_id} = $score; # If the CDS overlap is great, we keep the regular overlap, even if it is low
            }

           } #end of foreach hits

      }

     }#end of whilefor $chromosome_of
  } #end of outer foreach for $chromosome 

  my ($all_transcript_result_assigned, $all_tl_transcript_result_assigned) = 
    $self->compute_assignments(\%all_transcript_result, \%all_tl_transcript_result);
  
  while ( my ($refid, $ensids) = each( %$all_transcript_result_assigned ) ) {

    my $ens_stable_id = (keys %{$all_transcript_result_assigned->{$refid} })[0];
    my $best_score = $all_transcript_result_assigned->{$refid}->{$ens_stable_id};

    $self->write_to_rdf_store($ens_stable_id, $refid, $best_score, $species_id, $rdf_writer, $source, $core_dba, $other_dba);
  }
  ##Dump results

} #end of the routine

sub compute_assignments{
  my $self = shift;
  my ($all_transcript_result, $all_tl_transcript_result) = @_;

  while ( my ($refid, $ensids) = each( %$all_transcript_result ) ) {

    #if there are more than one ensembl transcript assignment to one refseq id, then choose the best one based on the score
    #if the score is the same then decide based on the translated score for that particular ensembl transcript
    if(scalar(keys %$ensids) > 1){

      my $highest_score_id =  (sort { $ensids->{$b} <=> $ensids->{$a} } keys(%$ensids) )[0];

      if(exists $all_tl_transcript_result->{$refid}){
        my %transcript_result;
        my %tl_transcript_result;

        %transcript_result = map { $_, $all_transcript_result->{$refid}->{$_} } keys %{$all_transcript_result->{$refid}};
        %tl_transcript_result = map { $_, $all_tl_transcript_result->{$refid}->{$_} } keys %{$all_tl_transcript_result->{$refid}};

        my ($best_score, $best_id) = $self->get_best_score_id(\%transcript_result, \%tl_transcript_result);
        $all_transcript_result->{$refid} = { $best_id => $best_score};
      }else{
        $all_transcript_result->{$refid} = { $highest_score_id => $ensids->{$highest_score_id}};
      }
    }
  } #end while


return ($all_transcript_result, $all_tl_transcript_result);
}


sub calculate_score {
  my $self = shift;
  my $hit = shift; # a single match in the region from our index
  my $ensembl_rr = shift; # RangeRegistry of Ensembl exons
  my $exons_ens = shift; # array of exons from Ensembl
  my $translating = shift; # calculate score considering only the translateable exons
  my ($id, $cdsStart, $cdsEnd);

  $id = $hit->{'id'};
  $cdsStart = $hit->{'cds_start'};
  $cdsEnd = $hit->{'cds_end'};
  my $exonStarts =  $hit->{'exon_starts'};
  my $exonEnds   =  $hit->{'exon_ends'} ;
  if ($translating) {
    ($exonStarts, $exonEnds) = $self->get_all_translateable_Exons($exonStarts, $exonEnds, $cdsStart, $cdsEnd);
  }
  my $exonCount = scalar(@$exonStarts);

  my $rr = Bio::EnsEMBL::Mapper::RangeRegistry->new();
  my $exon_match = 0;

  # register otherdata source exons and calculate overlap with Ensembl exons
  for(my $i=0; $i< $exonCount; $i++) {
    my $start = $exonStarts->[$i];
    my $end = $exonEnds->[$i];
    my $overlap = $ensembl_rr->overlap_size('exon', $start, $end);
    $exon_match += $overlap/($end - $start + 1);
    $rr->check_and_register('exon', $start, $end);
  }
  my $exon_match_ens = 0;

  # Calculate Ensembl exon overlap with otherdata exons
  foreach my $exon_ens (@$exons_ens) {
    my $start_ens = $exon_ens->seq_region_start();
    my $end_ens = $exon_ens->seq_region_end();
    my $overlap_ens = $rr->overlap_size('exon', $start_ens, $end_ens);
    $exon_match_ens += $overlap_ens/($end_ens - $start_ens + 1);
  }
  return 0 if @$exons_ens < 1;
  my $score;
  $score = ($exon_match_ens + $exon_match) / (scalar(@$exons_ens) + $exonCount );
  return $score;
}


# Check if the score crosses the threshold score (0.75)
# Compare the scores based on exon overlap
# If there is a stalemate, choose the one with the best translateable exon overlap score
sub get_best_score_id{
  my $self = shift;
  my ($transcript_result, $tl_transcript_result) = @_;

  my $best_score = 0;
  my $best_id;
  my $exon_score;
  my $tl_exon_score;

  my @options = sort { $b->[1] <=> $a->[1] || $b->[2] <=> $a->[2] }
                map { [
                        $_, 
                        $tl_transcript_result->{$_} || 0, 
                        $transcript_result->{$_} || 0
                    ] }
                keys %$transcript_result;
  return unless @options;

  ($best_id,$tl_exon_score,$exon_score) = @{shift @options};
  $best_score = $exon_score;

  return ($best_score, $best_id);
}


# Write the overlap xrefs to rdf store
sub write_to_rdf_store{
  my($self) = shift;
  my ($ens_stable_id, $best_id, $best_score, $species_id, $rdf_writer, $source, $core_dba, $other_dba) = @_;

  # If a best match was defined for the otherdata source transcript, store it as direct xref for ensembl transcript
  if (!$best_id) {
    Bio::EnsEMBL::Mongoose::UsageException->throw('Missing best_id is required when dumping Coordinate Overlap scores in RDF');
  }
  my ($acc, $version) = split(/\./, $best_id);
  my $transcript_source;
  my $protein_source;
  if ($source eq 'refseq') {
    $transcript_source = 'Refseq_dna';
    $protein_source = 'RefSeq_peptide';
  } elsif ($source eq 'ucsc') {
    $transcript_source = 'ucsc'
  }

  my $source_xref_transcript_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({id => $source eq 'refseq' ? $acc: $best_id, accessions => [qq/$acc/], });
  $rdf_writer->print_coordinate_overlap_xrefs($ens_stable_id,$source_xref_transcript_record,$transcript_source,$best_score);

  # Also store refseq protein as direct xref for ensembl translation, if translation exists.
  # Absence of an otherfeatures database adaptor means we skip the translation links.
  # if(defined $other_dba){ 
  #   my $ta_of = $other_dba->get_TranscriptAdaptor();
  #   my $t_of = $ta_of->fetch_by_stable_id($best_id);
  #   my $tl_of = $t_of->translation();
    
  #   my $ta = $core_dba->get_TranscriptAdaptor();
  #   my $t = $ta->fetch_by_stable_id($ens_stable_id);
  #   my $tl = $t->translation();
    
  #   if (defined $tl && defined $tl_of) {
  #     if ($tl_of->seq eq $tl->seq) {
  #       ($acc, $version) = split(/\./, $tl_of->stable_id());

  #       my $xref_translation_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({id => $source eq 'refseq' ? $acc : $tl_of->stable_id() , accessions => [qq/$acc/], });
  #       $rdf_writer->print_coordinate_overlap_xrefs($tl->stable_id(),$xref_translation_record,$protein_source,$best_score);

  #     }
  #   }
  # }

}

# Applies to Lucy index. Ensembl already knows how to get these
sub get_all_translateable_Exons {
  my $self = shift;
  my ($exonStarts, $exonEnds, $cdsStart, $cdsEnd ) = @_;
 
  my @tl_exonStarts;
  my @tl_exonEnds;
  my $start_index = -1;
  my $end_index = -1;
  
  #return an empty list if there is no translation (i.e. pseudogene)
  unless(defined $cdsStart && $cdsEnd) { return []; }
  
  for (my $i = 0;$i < scalar(@$exonStarts); $i++){
    if ($cdsStart > $$exonEnds[$i]) {
      next;   # Not yet in translated region
    }
    
    #cds start
    if($cdsStart >= $$exonStarts[$i] && $cdsStart <= $$exonEnds[$i]){
      $start_index = $i;
      $$exonStarts[$i] = $cdsStart;
    }
     #cds end
    if($cdsEnd >= $$exonStarts[$i] && $cdsEnd <= $$exonEnds[$i]){
      $end_index = $i;
      $$exonEnds[$i] = $cdsEnd;
    }
  }
  
  for (my $i = $start_index;$i <= $end_index; $i++){
    push(@tl_exonStarts, $$exonStarts[$i]);
    push(@tl_exonEnds, $$exonEnds[$i]);
    
  }

  return (\@tl_exonStarts, \@tl_exonEnds);
}








__PACKAGE__->meta->make_immutable;

1;
