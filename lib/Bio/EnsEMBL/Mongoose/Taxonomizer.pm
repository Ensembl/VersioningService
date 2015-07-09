# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Translate taxons into species names, and to get multiple taxons from child branches.

package Bio::EnsEMBL::Mongoose::Taxonomizer;
use Moose;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor;

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
    isa => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    is => 'ro',
    lazy => 1,
    builder => '_load_compara_db',
    
);

has ncbi_taxon_adaptor => (
    isa => 'Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor',
    is => 'ro',
    lazy => 1,
    builder => '_get_NCBI_adaptor',
);


sub _load_compara_db {
    my $self = shift;
    my $conf = $self->config;
    my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -user => $conf->{compara_user},
        -pass => $conf->{compara_pass},
        -host => $conf->{compara_host},
        -port => $conf->{compara_port},
        -dbname => $conf->{compara_db},
    );
    if (!$dba) {
        Bio::EnsEMBL::Mongoose::IOException->throw(
            message => 'Database connection issue. databases.conf must contain Compara DB credentials'
        );
    }
    return $dba;
}

sub _get_NCBI_adaptor {
    my $self = shift;
    my $ta = Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor->new(
        $self->dba
    );
    if (!$ta) {
        Bio::EnsEMBL::Mongoose::IOException->throw(
            message => 'Unable to create NCBITaxonAdaptor.'
        );
    }
    return $ta;
}

# These next two methods are used to retrieve one or many taxon IDs
sub fetch_nested_taxons {
    my $self = shift;
    my $taxon_id = shift;
    my $adaptor = $self->ncbi_taxon_adaptor;
    my $node = $adaptor->fetch_node_by_taxon_id($taxon_id);
    my $subtree = $adaptor->fetch_subtree_under_node($node);
    my $leaves = $subtree->get_all_nodes;
    my @xylem =  map {$_->taxon_id} @$leaves;
    return \@xylem;
}

sub fetch_taxon_id_by_name {
    my $self = shift;
    my $name = shift;
    my $adaptor = $self->ncbi_taxon_adaptor;
    my $node = $adaptor->fetch_node_by_name($name);
    if ($node) {
        return $node->ncbi_taxid();
    }
    return;
}





1;