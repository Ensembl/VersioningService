=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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
use Bio::EnsEMBL::Mongoose::Serializer::RDFCoordinateOverlap;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use File::Temp qw/ tempfile tempdir /;
use Data::Dumper;

=head2 create_temp_index

  Arg [1]    : Hash containing DBAdaptor (otherfeatures), analysis name (eg: refSeq_import), species name (eg: homo_sapiens)
  Example    : $mapper->create_temp_index({'species' => $species, 'dba' => $other_dba, 'analysis_name' => "refseq_import"});
  Description: Creates lucy index records from otherfeatures database in a temperory folder
  Returntype : String - Path of index folder

=cut

sub create_temp_index{
  my $self = shift;
  my $args = shift;
  
  my $dba = $args->{'dba'};
  my $analysis_name = $args->{'analysis_name'};
  my $species = $args->{'species'};
  
  # Use taxonomizer to convert name to taxid (homo_sapiens to 9606)
  my $taxonomizer = Bio::EnsEMBL::Mongoose::Taxonomizer->new();
  $species =~ s/_/ /;
  my $species_id = $taxonomizer->fetch_taxon_id_by_name($species);
  next unless defined $species_id;
  
  my $sa = $dba->get_SliceAdaptor();
  next unless defined $sa;
  my $chromosomes = $sa->fetch_all('chromosome', undef, 1);
  
  my $index_folder = tempdir( CLEANUP => 1 );
  my $doc_store = Bio::EnsEMBL::Mongoose::Persistence::LucyFeeder->new( index => $index_folder);
 
  my $logic_name;
  if($dba){
    # Fetch analysis object for refseq
    my $aa_of = $dba->get_AnalysisAdaptor();
  
    foreach my $ana(@{ $aa_of->fetch_all() }) {
      if ($ana->logic_name =~ /$analysis_name/) {
        $logic_name = $ana->logic_name;
      }
    }
    ## Not all species have refseq_import data, skip if not found
    if (!defined $logic_name) {
      print STDERR "No data found for refSeq_import, skipping import\n";;
      return undef;
    }
  } #if otherf_dba
  
  
  foreach my $chromosome (@{$chromosomes}) {
    my $chr_name = $chromosome->seq_region_name();
    my $genes = $chromosome->get_all_Genes($logic_name, undef, 1);
    
     while (my $gene = shift @$genes) {
      my $transcripts = $gene->get_all_Transcripts();
      my $strand = $gene->strand();
      
      # Create an  index of all ensembl Transcript as lucy Records
      foreach my $transcript (sort { $a->start() <=> $b->start() } @$transcripts) {
        if ($transcript->stable_id =~ /H3.X/ || $transcript->stable_id =~ /H3.Y/ || $transcript->stable_id =~ /^3.8/) { next; } #legacy code
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
  $record->id($transcript->stable_id());
  $record->taxon_id($species_id) if $species_id;

  $record->gene_name($transcript->stable_id());
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

  Arg [1]    : Hash containing 
               index_location (the source data index  eg: refseq or ucsc), 
               core_dba (db handler), 
               other_dba (db handler)
               rdf_writer (rdf writer handler)
               
  Example    : $mapper->calculate_overlap_score({'index_location' => $temp_index_folder , 'species' => $species, 
  	                                             'core_dba' => $core_dba, 'other_dba' => $other_dba,
  	                                             'rdf_writer' => $rdf_writer , 'source' => "refseq"});
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


sub calculate_overlap_score{
  my $self = shift;
  my $args = shift;
  
  my $index_location = $args->{'index_location'};
  my $species = $args->{'species'};
  my $core_dba = $args->{'core_dba'};
  my $other_dba = $args->{'other_dba'};
  my $rdf_writer = $args->{'rdf_writer'};
  my $source = $args->{'source'};
  
  my $taxonomizer = Bio::EnsEMBL::Mongoose::Taxonomizer->new();
  $species =~ s/_/ /;
  my $species_id = $taxonomizer->fetch_taxon_id_by_name($species);
  next unless defined $species_id;

  next unless defined $index_location and -e $index_location;
  my $lucy_query = Bio::EnsEMBL::Mongoose::Persistence::LucyQuery->new(config => { index_location => $index_location });
  
  my $sa = $core_dba->get_SliceAdaptor();
  my $chromosomes_ens = $sa->fetch_all('chromosome', undef, 1);
  
  # get all chromosomes from ensembl core db iterate through it
  foreach my $chromosome_ens (@{$chromosomes_ens}) {
    my $chr_name = $chromosome_ens->seq_region_name();
    my $genes_ens = $chromosome_ens->get_all_Genes(undef, 'core', 1);
    
     foreach my $gene_ens (@{$genes_ens}) {
       my $transcripts_ens = $gene_ens->get_all_Transcripts();
      
      # register all Ensembl exons and translateable exons in a RangeRegistry seperately
       foreach my $transcript_ens (sort { $a->start() <=> $b->start() } @$transcripts_ens) {

         my %transcript_result;
         my %tl_transcript_result;

         my $exons_ens = $transcript_ens->get_all_Exons();
         my $tl_exons_ens = $transcript_ens->get_all_translateable_Exons();
        
         my $rr1 = Bio::EnsEMBL::Mapper::RangeRegistry->new();
         my $rr3 = Bio::EnsEMBL::Mapper::RangeRegistry->new();
        
         # register ensembl exons
         foreach my $exon_ens (@$exons_ens) {
           my $start_ens = $exon_ens->seq_region_start();
           my $end_ens = $exon_ens->seq_region_end();
           $rr1->check_and_register( 'exon', $start_ens, $end_ens );
         }

         # register ensembl translateable exons
         foreach my $tl_exon_ens (@$tl_exons_ens) {
           my $tl_start_ens = $tl_exon_ens->seq_region_start();
           my $tl_end_ens = $tl_exon_ens->seq_region_end();
           $rr3->check_and_register( 'exon', $tl_start_ens, $tl_end_ens );
         }

          # pad the start and end as fixed width strings to enable sorting and searching with lucy (131555 to 000000000000131555)
          my $transcript_start = sprintf("%018d", $transcript_ens->start());
          my $transcript_end = sprintf("%018d", $transcript_ens->end());
        
          # fetch hits from otherdata source in lucy index (refseq or ucsc) that overlaps ensembl transcript start and end positions
          my $region_overlap_hits = $lucy_query->fetch_region_overlaps($species_id, $chr_name, $gene_ens->strand, $transcript_start, $transcript_end);
         
       
          # Create a range registry for all the exons and translateable exons of the otherdata source (eg: refseq) 
          my $id;
          foreach my $hit (@$region_overlap_hits){
            my ( $coord_xref_id, $accession, $txStart, $txEnd, $cdsStart, $cdsEnd);

            $id = $hit->{'id'};
            $accession = $hit->{'id'};
            $txStart = $hit->{'transcript_start'};
            $txEnd = $hit->{'transcript_end'};
            $cdsStart = $hit->{'cds_start'};
            $cdsEnd = $hit->{'cds_end'};
            my @exonStarts =  @{$hit->{'exon_starts'}};
            my @exonEnds   =  @{$hit->{'exon_ends'} };
            my $exonCount = scalar(@exonStarts);
           
            my $rr2 = Bio::EnsEMBL::Mapper::RangeRegistry->new();
            my $rr4 = Bio::EnsEMBL::Mapper::RangeRegistry->new();
            my $exon_match = 0;

            my ($tl_exonStarts, $tl_exonEnds) = $self->get_all_translateable_Exons(\@exonStarts, \@exonEnds, $cdsStart, $cdsEnd);
            my $tl_exonCount = scalar(@$tl_exonStarts);
            my $tl_exon_match = 0;
          
            # calculate the overlap of ensembl exons with the external transcript exons using the overlap_size() method in the RangeRegistry.
            # Note: $rr1 is the registry for ensembl exons and $rr3 is the registry for translateable ensembl exons

            # register otherdata source exons
            for(my $i=0; $i< $exonCount; $i++) {
              my $start = $exonStarts[$i];
              my $end = $exonEnds[$i];
              my $overlap = $rr1->overlap_size('exon', $start, $end);
              $exon_match += $overlap/($end - $start + 1);
              $rr2->check_and_register('exon', $start, $end);
            }

            # register otherdata source translateable exons
            for(my $i=0; $i< $tl_exonCount; $i++) {
              my $tl_start = $$tl_exonStarts[$i];
              my $tl_end = $$tl_exonEnds[$i];
              my $tl_overlap = $rr3->overlap_size('exon', $tl_start, $tl_end);
              $tl_exon_match += $tl_overlap/($tl_end - $tl_start + 1);
              $rr4->check_and_register('exon', $tl_start, $tl_end);
            }
           
            my $exon_match_ens = 0;
            my $tl_exon_match_ens = 0;

            # calculate the overlap of external transcript exons with the ensembl exons using the overlap_size() method in the RangeRegistry.
            # Note: $rr2 is the registry for otherdata source exons and $rr4 is the registry for otherdata source transateable exons
            foreach my $exon_ens (@$exons_ens) {
              my $start_ens = $exon_ens->seq_region_start();
              my $end_ens = $exon_ens->seq_region_end();
              my $overlap_ens = $rr2->overlap_size('exon', $start_ens, $end_ens);
              $exon_match_ens += $overlap_ens/($end_ens - $start_ens + 1);
            }

            foreach my $tl_exon_ens (@$tl_exons_ens) {
              my $tl_start_ens = $tl_exon_ens->seq_region_start();
              my $tl_end_ens = $tl_exon_ens->seq_region_end();
              my $tl_overlap_ens = $rr4->overlap_size('exon', $tl_start_ens, $tl_end_ens);
              $tl_exon_match_ens += $tl_overlap_ens/($tl_end_ens - $tl_start_ens + 1);
            }

            # comparing exon matching with number of exons to give a score
            my $score = ( ($exon_match_ens + $exon_match)) / (scalar(@$exons_ens) + $exonCount );
           
            # comparing translateable exon matching with number of translateable exons to give a score
            my $tl_score = 0;
            if (scalar(@$tl_exons_ens) > 0) {
              $tl_score = ( ($tl_exon_match_ens + $tl_exon_match)) / (scalar(@$tl_exons_ens) + $tl_exonCount );
            }

            # store the score in hash with stable_id as key
             $transcript_result{$id} = $score;
             $tl_transcript_result{$id} = $tl_score;
           
           } #end of foreach hits

        my $best_tl_score = 0;
        my ($score, $tl_score);

        my ($best_score, $best_id) = $self->get_best_score_id(\%transcript_result, \%tl_transcript_result);
        
        # If a best match was defined for the transcript, store it as direct xref for ensembl transcript
        if ($best_id) {
          $self->write_to_rdf_store($transcript_ens->stable_id, $best_id, $best_score, $species_id, $rdf_writer, $source, $core_dba, $other_dba);
        }
      }
     
     }#end of whilefor $chromosome_of
  } #end of outer foreach for $chromosose 
} #end of the routine


# Check if the score crosses the threshold score (0.75)
# Compare the scores based on coding exon overlap
# If there is a stale mate, choose best exon overlap score
sub get_best_score_id{
  my $self = shift;
  my ($transcript_result, $tl_transcript_result) = @_;
  
  my $transcript_score_threshold = 0.75;
  my $tl_transcript_score_threshold = 0.75;
  my $best_score = 0;
  my $best_tl_score = 0;
  my $best_id;
  my ($score, $tl_score);

  foreach my $tid (keys(%$transcript_result)) {
    $score = $transcript_result->{$tid};
    $tl_score = $tl_transcript_result->{$tid};

    if ($score > $transcript_score_threshold || $tl_score > $tl_transcript_score_threshold) {
      if ($tl_score >= $best_tl_score) {
        if ($tl_score > $best_tl_score) {
          $best_id = $tid;
          $best_score = $score;
          $best_tl_score = $tl_score;
        } elsif ($tl_score == $best_tl_score) {
           if ($score > $best_score) {
             $best_id = $tid;
             $best_score = $score;
           }
          }
      } elsif ($score >= $best_score) {
          $best_id = $tid;
          $best_score = $score;
        }
     }
  }
  return ($best_score, $best_id);
}

# finally write the overlap xrefs to rdf store
sub write_to_rdf_store{
  my($self) = shift;
  my ($ens_stable_id, $best_id, $best_score, $species_id, $rdf_writer, $source, $core_dba, $other_dba) = @_;

  # If a best match was defined for the otherdata source transcript, store it as direct xref for ensembl transcript
  if ($best_id) {
    my ($acc, $version) = split(/\./, $best_id);

    if($rdf_writer){
      my $source_xref_transcript_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({id => $best_id, accessions => [qw/$acc/], });
      $rdf_writer->print_coordinate_overlap_xrefs($ens_stable_id,$source_xref_transcript_record,$source."_transcript",$best_score);
    }

    # Also store refseq protein as direct xref for ensembl translation, if translation exists
    if(defined $other_dba){ 
      my $ta_of = $other_dba->get_TranscriptAdaptor();
      my $t_of = $ta_of->fetch_by_stable_id($best_id);
      my $tl_of = $t_of->translation();
      
      my $ta = $core_dba->get_TranscriptAdaptor();
      my $t = $ta->fetch_by_stable_id($ens_stable_id);
      my $tl = $t->translation();
      
      if (defined $tl && defined $tl_of) {
        if ($tl_of->seq eq $tl->seq) {
          ($acc, $version) = split(/\./, $tl_of->stable_id());

          if($rdf_writer){
            my $refseq_xref_translation_record = Bio::EnsEMBL::Mongoose::Persistence::Record->new({id => $tl_of->stable_id(), accessions => [qw/$acc/], });
            $rdf_writer->print_coordinate_overlap_xrefs($tl->stable_id(),$refseq_xref_translation_record,'refseq_translation',$best_score);
          }
        }
      }
    }# end of if 
  }

}

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
