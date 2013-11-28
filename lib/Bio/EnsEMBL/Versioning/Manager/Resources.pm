package Bio::EnsEMBL::Versioning::Manager::Resources;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Object::Resources;
use base qw(Bio::EnsEMBL::Versioning::Manager);

sub object_class { 'Bio::EnsEMBL::Versioning::Object::Resources' }

 __PACKAGE__->make_manager_methods('resources');



1;
