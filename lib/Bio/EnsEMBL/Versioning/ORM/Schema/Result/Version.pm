=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

use utf8;
package Bio::EnsEMBL::Versioning::ORM::Schema::Result::Version;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bio::EnsEMBL::Versioning::ORM::Schema::Result::Version

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");

=head1 TABLE: C<version>

=cut

__PACKAGE__->table("version");

=head1 ACCESSORS

=head2 version_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 source_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 revision

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 count_seen

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 record_count

  data_type: 'integer'
  is_nullable: 1

=head2 uri

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 index_uri

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "version_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "source_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "revision",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "created_date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "count_seen",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "record_count",
  { data_type => "integer", is_nullable => 1 },
  "uri",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "index_uri",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</version_id>

=back

=cut

__PACKAGE__->set_primary_key("version_id");

=head1 RELATIONS

=head2 source

Type: belongs_to

Related object: L<Bio::EnsEMBL::Versioning::ORM::Schema::Result::Source>

=cut

__PACKAGE__->belongs_to(
  "sources",
  "Bio::EnsEMBL::Versioning::ORM::Schema::Result::Source",
  { source_id => "source_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 version_runs

Type: has_many

Related object: L<Bio::EnsEMBL::Versioning::ORM::Schema::Result::VersionRun>

=cut

__PACKAGE__->has_many(
  "version_runs",
  "Bio::EnsEMBL::Versioning::ORM::Schema::Result::VersionRun",
  { "foreign.version_id" => "self.version_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-02-19 11:36:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KitGSPDXGQRzRPa5rD0pkg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
