package Bio::EnsEMBL::Versioning::Object;


use strict;
use warnings;

### Abstract base class for rose based data objects

use strict;
use warnings;

use base 'Rose::DB::Object';
use Bio::EnsEMBL::Versioning::DB;


sub init_db { Bio::EnsEMBL::Versioning::DB->new(); }


1;

