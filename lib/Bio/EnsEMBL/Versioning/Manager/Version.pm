package Bio::EnsEMBL::Versioning::Manager::Version;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Object::Version;
use base qw(Bio::EnsEMBL::Versioning::Manager);


sub object_class { 'Bio::EnsEMBL::Versioning::Object::Version' }

 __PACKAGE__->make_manager_methods('versions');


=head2 get_all_versions

    Arg [0]     : String; the name of the source
    Description : Returns all the available version for a given source
    Returntype  : ArrayRef; the list of versions

=cut

sub get_all_versions {
  my $self = shift;
  my $source = shift;

  my %versions;
  my $versions = $self->get_objects(
                         with_objects => ['source'],
                         query => [
                                   'source.name' => $source
                                  ],
                         distinct => 1);

  return $versions;
}

sub get_current {
  my $self = shift;
  my $source = shift;

  my %versions;
  my $versions = $self->get_objects(
                         with_objects => ['source'],
                         query => [
                                   'source.name' => $source,
                                   is_current => 1
                                  ],
                         distinct => 1);

  return $versions->[0];
}



1;
