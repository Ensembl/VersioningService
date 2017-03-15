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

# Translate taxons into species names, and to get multiple taxa from child branches.
# Automatically tries to connect to a Compara database to facilitate taxon resolution

package Bio::EnsEMBL::Mongoose::Taxonomizer;
use Moose;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyNodeAdaptor;
use Bio::EnsEMBL::Mongoose::IOException;

use Config::General;

has config_file => (
    isa => 'Str',
    is => 'ro',
    required => 1,
    default => sub {
        return "$ENV{MONGOOSE}/conf/databases.conf";
    }
);

has config => (
    isa => 'HashRef',
    is => 'ro',
    required => 1,
    default => sub {
        my $self = shift;
        my $conf = Config::General->new($self->config_file);
        my %opts = $conf->getall();
        return \%opts;
    },
);

has dba => (
    isa => 'Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor',
    is => 'ro',
    lazy => 1,
    builder => '_load_taxonomy_db',
    
);

has ncbi_taxon_adaptor => (
    isa => 'Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyNodeAdaptor',
    is => 'ro',
    lazy => 1,
    builder => '_get_NCBI_adaptor',
);


sub _load_taxonomy_db {
    my $self = shift;
    my $conf = $self->config;
    my $dba = Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor->new(
        -user => $conf->{tax_user},
        -pass => $conf->{tax_pass},
        -host => $conf->{tax_host},
        -port => $conf->{tax_port},
        -dbname => $conf->{tax_db},
    );
    if (!$dba) {
        Bio::EnsEMBL::Mongoose::IOException->throw(
            message => 'Database connection issue. databases.conf must contain Taxonomy DB credentials'
        );
    }
    return $dba;
}

sub _get_NCBI_adaptor {
    my $self = shift;
    my $ta = $self->dba->get_TaxonomyNodeAdaptor();
    if (!$ta) {
        Bio::EnsEMBL::Mongoose::IOException->throw(
            message => 'Unable to create TaxonomyNodeAdaptor.'
        );
    }
    return $ta;
}

# These next two methods are used to retrieve one or many taxon IDs
sub fetch_nested_taxons {
    my ($self, $taxon_id) = @_;

    my $adaptor = $self->ncbi_taxon_adaptor;
    my $node = $adaptor->fetch_by_taxon_id($taxon_id);

    return [ $taxon_id, @{$adaptor->fetch_descendant_ids($node)} ];
}

sub fetch_taxon_id_by_name {
    my $self = shift;
    my $name = shift;
    $name =~ s/_/ /g; # sanitise production names and the like into search strings
    my $adaptor = $self->ncbi_taxon_adaptor;
    my $node = $adaptor->fetch_by_taxon_name($name);
    if ($node) {
      return $node->taxon_id;
    }
    return;
}





1;
