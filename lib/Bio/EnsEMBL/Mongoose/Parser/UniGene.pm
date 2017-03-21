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

=head1 DESCRIPTION

This is a class which is used to parse the UniGene's Hs.seq.uniq file.
For more info about UniGene files, please refer: ftp://ftp.ncbi.nih.gov/repository/UniGene/Homo_sapiens/

grep -A3 '\bHs.34012\b' Hs.seq.uniq 
>gnl|UG|Hs#S1731803 Homo sapiens breast cancer 2, early onset (BRCA2), mRNA /cds=p(228,10484) /gb=NM_000059 /gi=119395733 /ug=Hs.34012 /len=11386
GTGGCGCGAGCTTCTGAAACTAGGCGGCAGAGGCGGAGCCGCTGTGGCACTGCTGCGCCT
CTGCTGCGCCTCGGGTGTCTTTTGCGGCGGTGGGTCGCCGCCGGGAGAAGCGTGAGGGGA
CAGATTTGTGACCGGCGCGGTTTTTGTCAGCTTACTCCGGCCAAAAAAGAACTGCACCTC
=cut

package Bio::EnsEMBL::Mongoose::Parser::UniGene;
use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use Bio::EnsEMBL::Mongoose::IOException;
use Try::Tiny;
use Digest::MD5;
use File::Basename;

has 'taxon_id' => ( is => 'rw', isa => 'Int', default => 0 );


# Consumes UniGene files and emits Mongoose::Persistence::Records
with 'Bio::EnsEMBL::Mongoose::Parser::Parser','MooseX::Log::Log4perl';

sub read_record {
  my $self = shift;
  return unless defined $self->taxon_id;
  
  $self->clear_record;
  
  #set the line delimiter to \n>
  local $/ = "\n>";

  my $record = $self->record;
  my $fh      = $self->source_handle;
  my $content = <$fh>;
  return unless $content;

   if ($content) {
    chomp($content);

    my ($header, $sequence) = split("\n", $content,2);
    return unless defined($header) and defined($sequence);

    my ($cds_start, $cds_end, $gb_accession, $gb_description, $ug_identifier, $seq_length) = $self->process_header($header);
    return unless defined $ug_identifier;

    $record->id($ug_identifier);
    $record->display_label($ug_identifier);
    $record->description( $gb_description) if $gb_description;
    $record->cds_start($cds_start) if $cds_start;
    $record->cds_end($cds_end) if $cds_end;
    $record->taxon_id($self->taxon_id);
    
    if($gb_accession){
      $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => "GenBank",creator => 'UniGene',id => $gb_accession));
    }

    my @seq_lines = split (/\n/, $sequence);
    $sequence = uc(join("", @seq_lines));
    if ($sequence) {
      $record->sequence( $sequence );
      $record->sequence_length(length($sequence));
      my $digest = Digest::MD5->new;
      $digest->add($sequence);
      $record->checksum($digest->hexdigest);
    }
   }
  return 1;
}

sub process_header{
  my $self = shift;
  my $header = shift;
  my @header_fields = split("\/",$header);
  
  my ($cds_start, $cds_end, $gb_accession, $gb_description, $ug_identifier, $seq_length);
  foreach my $field (@header_fields){
     next if length($field) < 1;
     
     if($field =~ /cds\=p\((\d+),(\d+)\).*/){
       $cds_start = $1;
       $cds_end = $2;
     }
     
     if($field =~ /gb\=(\w+).*/){
       $gb_accession = $1;
     }
     
     if($field =~ /^>?gnl\|UG\|(.*?)\s+(.*?)\,.*/){
       $gb_description = $2;
     }
     
     if($field =~ /ug\=(\w+\.\w+).*/){
       $ug_identifier = $1;
     }
     
     if($field =~ /len\=(\d+).*/){
       $seq_length = $1;
     }
    
  }
  
  return ($cds_start, $cds_end, $gb_accession, $gb_description, $ug_identifier, $seq_length);

}

#
# Determine taxon ID, which is derived by parsing the source file name
# eg: 9606_Hs.seq.uniq.gz
#
sub BUILD {
  my $self = shift;

  if ($self->source_file) {
    my $source_file = $self->source_file;
    my ($taxid_species_code, $feature_type, $suffix) = fileparse($source_file, qr/\..*/);
    return if $taxid_species_code =~ 'README';
    my ($taxon_id, $species_code) = split('_', $taxid_species_code);

    if($taxon_id){
      $self->taxon_id($taxon_id);
    }else{
      Bio::EnsEMBL::Mongoose::IOException->throw ("Must supply source_file argument");
    }
  }

};
