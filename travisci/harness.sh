#!/bin/bash

ENSDIR="${ENSDIR:-$PWD}"

export PERL5LIB=$ENSDIR/bioperl-live:$ENSDIR/ensembl/modules:$ENSDIR/ensembl-test/modules:$ENSDIR/ensembl-io/modules:$ENSDIR/ensembl-hive/modules:$ENSDIR/ensembl-taxonomy/modules
export TEST_AUTHOR=$USER
export TEST_POD=1
export FUSEKI_HOME=$ENSDIR/apache-jena-fuseki-2.4.1/
export PATH=$FUSEKI_HOME/bin:$PATH # allow to find s-put for fuseki integration tests

cp conf/databases.conf.example conf/databases.conf
cp conf/test.conf.example conf/test.conf

echo "Running test suite"
prove -vl
prove -vl t/awkward-tests

exit $?
