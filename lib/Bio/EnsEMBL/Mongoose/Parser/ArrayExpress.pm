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

Bio::EnsEMBL::Mongoose::Parser::ArrayExpress - A class to parse ArrayExpress's files

=head1 DESCRIPTION

This is a class which is used to Parse the ArrayExpress's files from
ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/atlas/bioentity_properties/ensembl/

As of writing, the source file is tab limited text file and has the following 22 columns
Limiting to only ens(gene|protein|transcript).tsv files

ensgene description embl ensfamily ensfamily_description ensprotein enstranscript entrezgene gene_biotype go goterm hgnc_symbol interpro interproterm mirbase_accession mirbase_id ortholog refseq symbol unigene uniprot synonym

=cut

package Bio::EnsEMBL::Mongoose::Parser::ArrayExpress;
use Moose;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::IOException;
with 'Bio::EnsEMBL::Mongoose::Parser::Parser', 'MooseX::Log::Log4perl';


use File::Basename;
use Bio::EnsEMBL::Mongoose::Taxonomizer;
use Try::Tiny;

has 'taxonomizer' => (
    isa => 'Bio::EnsEMBL::Mongoose::Taxonomizer',
    is => 'ro',
    lazy => 1,
    default => sub {
        return Bio::EnsEMBL::Mongoose::Taxonomizer->new;
    }
);


has 'fields' => ( is => 'ro', isa => 'HashRef[Str]', default => sub { {} }, );
has 'feature_type' => ( is => 'rw', isa => 'Str', default => "" );
has 'taxon_id' => ( is => 'rw', isa => 'Int', default => 0 );


sub read_record {
  my $self = shift;
  $self->clear_record;
  my $record  = $self->record;
  my $fh      = $self->source_handle;
  my $content = <$fh>;
  return unless $content;
	
  #check if the line is a header line
  if ( $content =~ /^(ensgene|ensprotein|enstranscript)/ ) {
    $self->log->info("Processing header");
    chomp($content);

    $self->set_fields($content);
    
    do{
      $content = <$fh>;
    } until($content !~ /^(ensgene|ensprotein|enstranscript)/ );

    return unless $content;

    }

  if ( defined $self->fields && scalar( keys $self->fields ) > 0 ) {
    chomp($content);
    my $fields = $self->fields;
    my @linecolumns = split( /\t/, $content );
    my $id = $linecolumns[ $fields->{$self->feature_type} ];
    $record->id( $id );
    $record->display_label($id );
    my $description = $linecolumns[ $fields->{"description"} ];
    $record->description( $description) if $description;
    $record->taxon_id($self->taxon_id);
    
    my $gene_name = $linecolumns[ $fields->{"hgnc_symbol"} ];
    if($gene_name){
      $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'HGNC',creator => 'ArrayExpress',id => $gene_name));
    }
    # Strip out specific xrefs from columns, unpack them and add them to the record
    foreach my $source (qw/entrezgene mirbase_id refseq unigene uniprot interpro/) {
      my $ids;
      if (exists $fields->{$source} and defined($linecolumns[ $fields->{$source}]) and length($linecolumns[ $fields->{$source}]) > 0) {
        $ids = $self->split_value($linecolumns[ $fields->{$source} ]);
      }
      $record = $self->add_ae_xref($record, $ids, $source);
    }
    $record = $self->add_ae_xref($record, [$record->id], 'ensembl');


    if (exists $fields->{"synonym"} and defined($linecolumns[ $fields->{"synonym"}]) and length($linecolumns[ $fields->{"synonym"}]) > 0) {
      my $synonyms = $self->split_value($linecolumns[ $fields->{"synonym"}]);
      foreach my $synonym (@$synonyms){
        $record->add_synonym($synonym);
      }
    
    }

  return 1;
  }
	
}

=head2 set_fields
  
  Arg [1]     : String $header - file header line as string
  Example     : $self>set_fiels($header_string);
  Description : Setter for headers used in this file format
  Returntype  : Void

=cut

sub set_fields {
  my ( $self, $header ) = @_;
  my @actual_fields = split( /\t/, $header );
  my $feature_type = $actual_fields[0];
  $self->feature_type($feature_type);
  my $index = 0;

  foreach my $field (@actual_fields) {
    $self->fields->{$field} = $index++;
  }
}

=head2 split_value
  
  Arg [1]     : String $value - value from file seperated with @@ eg: A0A087WYV6@@A0A087WZU5@@O43657
  Example     : $self>split_value($value);
  Description : Splits the string in to multiple identifiers if string contains @@
  Returntype  : ArrayRef

=cut

sub split_value{
  my $self = shift;
  my $value = shift;
  
  my @values = ();
  if($value =~ /@@/g){
    @values = split('@@',$value);
   }else{
    push(@values,$value) if length($value) > 0;
  }
  
  return \@values;
}

#
# Add the list of xref ids from the given source to the record
#
sub add_ae_xref{
  my ($self, $record, $xref_ids, $source)  = @_;
  $source = 'mirbase' if $source eq 'mirbase_id'; # convert ArrayExpress source name to match other sources
  $source = 'Uniprot/SPTREMBL' if $source eq 'uniprot'; # convert uniprot source to a more recognisable source name

  foreach my $id (@$xref_ids){
    $record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => $source,creator => 'ArrayExpress',id => $id));
  }
  return $record;
}


#
# Determine taxon ID, which is derived by looking at the source file name
# eg: homo_sapiens.ensgene.tsv

#
sub BUILD {
  my $self = shift;

  if ($self->source_file) {
    my $source_file = $self->source_file;
    my ($species_name, $feature_type, $suffix) = fileparse($source_file, qr/\..*/);
    my $taxon_id = $self->taxonomizer->fetch_taxon_id_by_name($species_name);
    if($taxon_id){
      $self->taxon_id($taxon_id);
    }else{
      Bio::EnsEMBL::Mongoose::IOException->throw ("Must supply source_file argumen, or encountered an unexpected file name format");
    }
  }

};

__PACKAGE__->meta->make_immutable;
