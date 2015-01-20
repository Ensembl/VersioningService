package Bio::EnsEMBL::Mongoose::Parser::MIM2Gene;
use Modern::Perl;
use Moose;
use Moose::Util::TypeConstraints;
use Bio::EnsEMBL::Mongoose::Persistence::Record;
use Bio::EnsEMBL::Mongoose::Persistence::RecordXref;
use Try::Tiny;
use Bio::EnsEMBL::Mongoose::IOException;
with 'Bio::EnsEMBL::Mongoose::Parser::Parser';
with 'MooseX::Log::Log4perl';

# consumes the mim2gene.txt file
# see also primary parser consuming omim.txt file
# MIM provides two different datasets in one download; morbidities and gene data
# Variation requires the disease information later on, but it does not play a part in Xrefs

sub read_record { 
  my $self = shift;

  $self->clear_record;
  $self->record->taxon_id(9606); # Mendelian inheritance in man after all.
  
  my $fh = $self->source_handle;
  my $content = <$fh>;
  if ($content =~ /^#/) {$content = <$fh>} # crudely skip over comment lines
  return unless $content;
  chomp($content);
  # MIM id, gene/phenotype/both, EntrezGene ID, gene symbol like ACR or ALDH2
  my ($id,$type,$gene_id,$symbols) = split "\t",$content; # symbol currently ignored
  Bio::EnsEMBL::Mongoose::IOException->throw ('Insufficient data in line of mim2gene:'.$content) unless ($id && $gene_id);
  $self->record->id($id);
  $self->record->add_xref(Bio::EnsEMBL::Mongoose::Persistence::RecordXref->new(source => 'MIM',creator => 'MIM',id => $gene_id));
  
  return 1;
}


__PACKAGE__->meta->make_immutable;