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

=head1 NAME


=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Mongoose::Parser::UCSC;

use Moose;

use File::Basename;
use Bio::EnsEMBL::Mongoose::IOException;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;

with 'Bio::EnsEMBL::Mongoose::Parser::Parser', 'MooseX::Log::Log4perl';

has 'synonyms_to_taxon' => (
    traits => ['Hash'],
    isa => 'HashRef[Int]',
    is => 'ro',
    default => sub {
        {
            hg38 => 9606,
            mm10 => 10090
        }
    },
    handles => {
        synonym_known => 'exists',
    }
);

#
# TODO
# - taxon ID?
# - the original parser creates a coordinate-based xref to handle
#   coordinates info in the UCSC file.
#   What should we do? Specialise Record class with additional attributes?
#
sub read_record {
  my $self = shift;
  $self->clear_record;
  my $record  = $self->record;
  
  my $fh = $self->source_handle;
  my $content = <$fh>;
  return unless $content; # skip if empty record
    
  chomp($content);
  $content =~ s/\s*$//;

  # Each line will have the following tab-delimited fields:
  # 0.    name        (UCSC stable ID)
  # 1.    chrom       (chromosome name, a la UCSC)
  # 2.    strand      (plus or minus)
  # 3.    txStart     (transcript start)
  # 4.    txEnd       (transcript end)
  # 5.    cdsStart    (CDS start)
  # 6.    cdsEnd      (CDS end)
  # 7.    exonCount   (number of exons in transcript)
  # 8.    exonStarts  (comma-separated list of exon start positions)
  # 9.    exonEnds    (comma-separated list of exon end positions)
  # 10.   proteinID   (cross reference to a protein ID, e.g. UniProt)
  # 11.   alignID     (not sure what this is right now, but it often links to Ensembl transcripts, or other UCSC accessions)
  
  my @fields = split( /\t/, $content );
  my ( $name,
       $chrom,
       $strand,
       $txStart,
       $txEnd,
       $cdsStart,
       $cdsEnd,
       $exonStarts,
       $exonEnds ) = @fields[ 0 .. 6, 8, 9];
  my $protein_id = $fields[10];

  # UCSC uses slightly different chromosome names, at least for
  # human and mouse, so chop off the 'chr' in the beginning.  We do
  # not yet translate the names of the special chromosomes, e.g.
  # "chr6_cox_hap1" (UCSC) into "c6_COX" (Ensembl).
  $chrom =~ s/^chr//;

  # They also use '+' and '-' for the strand, instead of -1, 0, or 1.
  if    ( $strand eq '+' ) { $strand = 1 }
  elsif ( $strand eq '-' ) { $strand = -1 }
  else                     { $strand = 0 }

  # ... and non-coding transcripts have cdsStart == cdsEnd.  We would
  # like these to be stored as NULLs.
  if ( $cdsStart == $cdsEnd ) {
    undef($cdsStart);
    undef($cdsEnd);
  }

  # ... and they use the same kind of "inbetween" coordinates as e.g.
  # exonerate, so increment all start coordinates by one.
  $txStart += 1;
  $exonStarts = join( ',', map( { $_ +1 } split( /,/, $exonStarts ) ) );
  if ( defined($cdsStart) ) { $cdsStart += 1 }

  # Cut off the last comma from $exonEnds, if it exists.  This is done
  # for $exonStarts already (above).
  if ( substr( $exonEnds, -1, 1 ) eq ',' ) { chop($exonEnds) }

  # set all relevant attributes to compose a coordinate xref like record  
  $record->id($name);
  $record->taxon_id($self->{taxon_id}) if $self->{taxon_id};
  $name =~ s/\.\d$//;
  $record->entry_name($name);
  $record->display_label($name);
  $record->chromosome($chrom);
  $record->strand($strand);
  $record->transcript_start($txStart);
  $record->transcript_end($txEnd);
  $record->cds_start($cdsStart) if $cdsStart;
  $record->cds_end($cdsEnd) if $cdsEnd;
  $record->exon_starts([ split /,/, $exonStarts ]);
  $record->exon_ends([ split /,/, $exonEnds ]);
  
  # add xrefs to protein IDs
  if ($protein_id) {
    my $source;
    if ($protein_id =~ /^[A-Z0-9]{6,10}$/) {
      $source = 'UniProtKB';
    } elsif ($protein_id =~ /^ENS/) {
      $source = 'ensembl_protein';
    } elsif ($protein_id =~ /^NP/) {
      $source = 'RefSeq';
    } else {
      # Bio::EnsEMBL::Mongoose::IOException->throw ("Unknown source for protein ID: $protein_id")
      return 1;
      # Can't trivially write a regex to anticipate isoforms, all Ensembl ID types and RefSeq types
    }
    $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source, creator => 'UCSC', id => $protein_id));
  }
  
  return 1;
}

#
# Determine taxon ID, which is derived by looking at the source file name
# for a component of it (the prefix) which is assumed to be the UCSC official
# assembly name.
#
# This is because, to the best of my knowledge, there's no taxon info in UCSC
# so the Downloader is forced to download the corresponding file to a target
# which containts the synonym which can then be mapped to taxon using the
# synonym_to_taxon member
#
sub BUILD {
  my $self = shift;

  if ($self->source_file) {
    my $source_file = $self->source_file;

    my ($ucsc_assembly_name, $dirs, $suffix) = fileparse($source_file, qr/\..*/);
    $self->{taxon_id} = $self->{synonyms_to_taxon}{$ucsc_assembly_name}
      if $ucsc_assembly_name and $self->synonym_known($ucsc_assembly_name);
  } else {
    Bio::EnsEMBL::Mongoose::IOException->throw ("Must supply source_file argument")
  }
};

__PACKAGE__->meta->make_immutable;
