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

=head1 DESCRIPTION

Responsible for turning pairs of species and Xref source into an alignment method to apply. 
It also defines what parameters are set to given a particular method name. Used by ExonerateAligner

=head1 SYNOPSIS

my $method_string = $method_factory->get_method_by_species_and_source('gopher','holes');

if ($method_factory->valid_method($method_string) ) {
  print "$method_string is the chosen method";
  ...
};

=cut
package Bio::EnsEMBL::Mongoose::Utils::AlignmentMethodFactory;

use Moose;
use Moose::Util::TypeConstraints;

has method_matrix => (
  is => 'ro',
  isa => 'HashRef', 
  builder => '_populate_method_matrix', 
  traits => ['Hash'],
  handles => {
    are_you_there => 'exists',
    get_methods_by_source => 'get',
  }
);
sub _populate_method_matrix {
  my $self = shift;
  # this is where you'd read a config file if you need to
  # I suspect this approach to configuring aligners will get us into trouble with bacteria
  # These strings are used by ExonerateAligner
  my $matrix = {
    default => {
      default => 'top5_90%'
    },
    uniprot => {
      default => 'best_exact'
    },
    refseq => {
      default => 'top5_90%',
      aedes_aegypti => 'best_exact',
      anopheles_gambiae => 'top5_55%',
      culex_pipiens => 'top5_55%',
      culex_quinquefasciens => 'top5_55%',
      drosophila_melanogaster => 'best_exact',
      saccharomyces_cerevisiae => 'best_exact',
      pep => 'top5_20%' # RefSeq peptides can be weakly aligned and still be assigned
    },
  };
}

# Range of criteria for alignment selection
has preset_methods => (
  is => 'ro', 
  isa => 'HashRef', 
  traits => ['Hash'], 
  handles => { 
    valid_method => 'exists',
    method_names => 'keys',
    fetch_method => 'get'
  },
  default => sub {{
    best_exact => {
      query_score => 1,
      target_score => 1,
      n => 1
    },
    'best_90%' => {
      query_score => 0.9,
      target_score => 0.9,
      n => 1
    },
    'top5_90%' => {
      query_score => 0.9,
      target_score => 0.9,
      n => 5
    },
    'top5_20%' => {
      query_score => 0.2,
      target_score => 0.2,
      n => 5
    },
    top5_asymmetric => {
      query_score => 0.95,
      target_score => 0.70,
      n => 5
    },
    'top_5_55%' => {
      query_score => 0.55,
      target_score => 0.55,
      n => 5
    }
}});

sub get_method_by_species_and_source {
  my ($self,$species, $source, $seq_type) = @_;
  my $method;
  if ($self->are_you_there(lc $source) ) {
    # species-specific mode choice
    my $methods = $self->get_methods_by_source(lc $source);
    if (exists $methods->{$species}) {
      return $methods->{$species};
    } else {
      if ($seq_type && exists $methods->{$seq_type}) {
        return $methods->{$seq_type};
      }
      # default for source
      return $methods->{default};
    }
  } else {
    # global default
    return $self->get_methods_by_source('default')->{default};
  }
  
}


1;
