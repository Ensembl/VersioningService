
# General dependencies
requires 'Config::General';
requires 'PerlIO::gzip';

requires 'JSON::XS';
requires 'JSON::Any';
requires 'XML::LibXML';
requires 'Log::Log4perl';
requires 'Compress::Snappy';
requires 'Sereal';

# Moose dependencies

requires 'Moose';
requires 'Moose::Role';
requires 'MooseX::Log::Log4perl';
requires 'MooseX::Storage';
requires 'Throwable::Error';

# Lucy dependencies

requires 'Lucy';
requires 'Lucy::Index::Indexer';
requires 'Lucy::Plan::Schema';
requires 'Lucy::Search::IndexSearcher';
requires 'Lucy::Search::QueryParser';
requires 'Search::Query';

requires 'Search::Query::Dialect::Lucy';
