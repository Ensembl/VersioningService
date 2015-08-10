
# General dependencies
requires 'Config::General';
requires 'PerlIO::gzip';
requires 'Modern::Perl';

requires 'REST::Client';
requires 'JSON::XS';
requires 'JSON::Any';
requires 'JSON::SL';
requires 'XML::LibXML';
requires 'Log::Log4perl';
requires 'Compress::Snappy';
requires 'Sereal';

# Moose dependencies

requires 'Moose';
requires 'Moose::Role';
requires 'MooseX::Log::Log4perl';
requires 'MooseX::Storage';
requires 'Method::Signatures';
requires 'Throwable::Error';

# Testing

requires 'Test::Differences';
requires 'Test::JSON';
requires 'Test::MockObject';
requires 'Test::MockObject::Extends';
requires 'Test::Exception';
requires 'Class::Inspector';
requires 'namespace::sweep';
requires 'Module::Load::Conditional';

# Lucy dependencies

requires 'Lucy', '>= 0.3.3';
requires 'Lucy::Index::Indexer';
requires 'Lucy::Plan::Schema';
requires 'Lucy::Search::IndexSearcher';
requires 'Lucy::Search::QueryParser';
requires 'Search::Query';

requires 'Search::Query::Dialect::Lucy';

# DBIx

requires 'DBIx::Class';
requires 'DBIx::Class::TimeStamp';
requires 'MooseX::MarkAsMethods'; # needed for Moosed DBICs
requires 'MooseX::NonMoose'; # needed for Moosed DBICs

recommends 'DBIx::Class::Schema::Loader';

# Graphing

requires 'RDF::Query::Client';
