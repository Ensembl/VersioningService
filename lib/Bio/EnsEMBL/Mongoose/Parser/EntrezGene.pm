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

=head1 NAME

Bio::EnsEMBL::Mongoose::Parser::EntrezGene - A class to parse EntrezGene's gene_info file

=head1 DESCRIPTION

This is a class which is used to Parse the EntrezGene's gene_info.gz file.
As of writing, the source file is zipped tab limited text file and has the following 15 columns

tax_id GeneID Symbol LocusTag Synonyms dbXrefs chromosome map_location description type_of_gene Symbol_from_nomenclature_authority Full_name_from_nomenclature_authority Nomenclature_status Other_designations Modification_date);

For more info about gene_info file, please refer: ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/README
=cut

package Bio::EnsEMBL::Mongoose::Parser::EntrezGene;
use Moose;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
with 'Bio::EnsEMBL::Mongoose::Parser::Parser', 'MooseX::Log::Log4perl';

has 'fields' => ( is => 'ro', isa => 'HashRef[Str]', default => sub { {} }, );

sub read_record {
  my $self = shift;
  $self->clear_record;
  my $record  = $self->record;
  my $fh      = $self->source_handle;
  my $content = <$fh>;
  return unless $content;
	
  #check if the line is a header line
  if ( $content =~ /^#/ ) {
    $self->log->info("Processing gene_info header");
    chomp($content);

    #remove the first character '#'
    $content = substr $content, 1;
    $self->set_fields($content);
	
    do{
      $content = <$fh>;
    } until($content !~ /^#/ );
    
    return unless $content;
    }

  if ( defined $self->fields && scalar( keys $self->fields ) > 0 ) {
    chomp($content);
    my $fields = $self->fields;
    my @linecolumns = split( /\t/, $content );
    $record->id( $linecolumns[ $fields->{"GeneID"} ] );
    $record->entry_name( $linecolumns[ $fields->{"Symbol"} ] );
    $record->display_label($linecolumns[ $fields->{"Symbol"} ] );
    $record->description($linecolumns[ $fields->{"description"} ] );
    $record->taxon_id($linecolumns[ $fields->{"tax_id"} ] );
		
    #xref format MIM:600950|HGNC:HGNC:19|Ensembl:ENSG00000129673|HPRD:02974|Vega:OTTHUMG00000180179
    #Please note that HGNC is different from others
    my $xrefs = $linecolumns[ $fields->{"dbXrefs"} ];
    unless ($xrefs eq "-"){
			
    if(defined $xrefs && index($xrefs, '|') > 0 ){
      my @all_xrefs = split(/\|/,  $xrefs);

      foreach my $xref (@all_xrefs){
        my ($source,$id);
        if($xref =~/HGNC/g){
          ($source,$id) = split(/:HGNC:/, $xref);
          $id = 'HGNC:'.$id;
        }else{
          ($source,$id) = split(/:/, $xref);
        }
        $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source,creator => 'EntrezGene',id => $id));
      }
    }
  }

  #synonym format one string (eg: DSPSI) or multipe with '|' token seperated (eg: DSPS|SNAT)
  my $synonyms = $linecolumns[ $fields->{"Synonyms"} ];
  unless ($synonyms eq "-"){
    if(defined $synonyms && index($synonyms, '|') > 0 ){
      my @all_synonyms = split(/\|/,  $synonyms);

      foreach my $synonym (@all_synonyms){
        $record->add_synonym($synonym);
      }
    }else{
      $record->add_synonym($synonyms);
    }
  }
  return 1;
  }
	
}



=head2 set_fields
  
  Arg [1]     : String $header - gene_info file header line as string
  Example     : $self>set_fiels($header_string);
  Description : Setter for headers used in this file format
  Returntype  : Void

=cut

sub set_fields {
  my ( $self, $header ) = @_;
  my @actual_fields = split( /\t/, $header );
  my $index = 0;

  foreach my $field (@actual_fields) {
    $self->fields->{$field} = $index++;
  }
}

1;
