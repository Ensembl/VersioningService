package Bio::EnsEMBL::Versioning::Manager::SourceGroup;

use strict;
use warnings;

use Bio::EnsEMBL::Versioning::Object::SourceGroup;
use base qw(Bio::EnsEMBL::Versioning::Manager);

sub object_class { 'Bio::EnsEMBL::Versioning::Object::SourceGroup' }

 __PACKAGE__->make_manager_methods('source_groups');



1;
