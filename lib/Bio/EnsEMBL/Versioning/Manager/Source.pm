package Bio::EnsEMBL::Versioning::Manager::Source;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Object::Source;
use base qw(Bio::EnsEMBL::Versioning::Manager);

sub object_class { 'Bio::EnsEMBL::Versioning::Object::Source' }

 __PACKAGE__->make_manager_methods('sources');



1;
