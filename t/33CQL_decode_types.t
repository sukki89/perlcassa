#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More;
use Math::BigInt;
use Math::BigFloat;

use Data::Dumper;

$|++;

use vars qw($test_host $test_keyspace);

# Load default connect values from helper script??
# and actually use them?
$test_host = 'localhost';
$test_keyspace = 'xx_testing_cql';

plan tests => 19;

require_ok( 'perlcassa' );

my $dbh;

$dbh = new perlcassa(
    'hosts' => [$test_host],
    'keyspace' => $test_keyspace,
);

my $res;

$res = $dbh->exec("CREATE TABLE $test_keyspace.all_types ( 
    pk text PRIMARY KEY,
    first_name text,
    last_name text,
    t_ascii ascii,
    t_bigint bigint,
    t_blob blob,
    t_boolean boolean,
    t_decimal decimal, 
    t_double double,
    t_float float,
    t_inet inet,
    t_int int,
    t_text text,
    t_timestamp timestamp,
    t_timeuuid timeuuid,
    t_uuid uuid,
    t_varchar varchar,
    t_varint varint,
) WITH COMPACT STORAGE");
ok($res, "Create test table.");

# Check the text types
$res = $dbh->exec("INSERT INTO all_types (pk, t_ascii, t_text, t_varchar) VALUES ('strings_test', 'v_ascii', 'v_text', 'v_v\xC3\xA1rchar')");
$res = $dbh->exec("SELECT pk, t_ascii, t_text, t_varchar FROM all_types WHERE pk = 'strings_test'");
my $row_text = $res->fetchone();
is($row_text->{t_ascii}->{value}, 'v_ascii', "Check ascii type.");
is($row_text->{t_text}->{value}, 'v_text', "Check text type.");
TODO: {
    # TODO check UTF8 support
    local $TODO = "UTF8 strings are not implemented";
    is($row_text->{t_varchar}->{value}, "v_v\xC3\xA1rchar", "Check varchar type.");
}

# Check boolean true and false
$res = $dbh->exec("INSERT INTO all_types (pk, t_boolean) VALUES ('bool_test', false)");
$res = $dbh->exec("SELECT pk, t_boolean FROM all_types WHERE pk = 'bool_test'");
my $row_01 = $res->fetchone();
is($row_01->{t_boolean}->{value}, 0, "Check boolean false.");
$res = $dbh->exec("INSERT INTO all_types (pk, t_boolean) VALUES ('bool_test', true)");
$res = $dbh->exec("SELECT pk, t_boolean FROM all_types WHERE pk = 'bool_test'");
my $row_02 = $res->fetchone();
is($row_02->{t_boolean}->{value}, 1, "Check boolean true.");

# Check floating point types
my $float1_s = '62831853071.7958647692528676655900576839433879875021';
my $float1 = Math::BigFloat->new($float1_s);
my $param_fp1 = { dv => 1234.5, fv => 9.875, av => $float1, };
$res = $dbh->exec("INSERT INTO all_types (pk, t_float, t_double, t_decimal) VALUES ('float_test1', :fv, :dv, :av)", $param_fp1);
$res = $dbh->exec("SELECT pk, t_float, t_double, t_decimal FROM all_types WHERE pk = 'float_test1'");
my $row_fp1 = $res->fetchone();
is($row_fp1->{t_double}->{value}, 1234.5, "Check double value.");
is($row_fp1->{t_float}->{value}, 9.875, "Check float value.");
is($row_fp1->{t_decimal}->{value}, $float1_s,
    "Check decimal (arbitrary precision float) value.");

my $float2_s = '-0.00000000000000000000000000167262177';
my $float2 = Math::BigFloat->new($float2_s);
my $param_fp2 = { dv => -0.000012345, fv => -0.5, av => $float2 };
$res = $dbh->exec("INSERT INTO all_types (pk, t_float, t_double, t_decimal) VALUES ('float_test2', :fv, :dv, :av)", $param_fp2);
$res = $dbh->exec("SELECT pk, t_float, t_double, t_decimal FROM all_types WHERE pk = 'float_test2'");
my $row_fp2 = $res->fetchone();
is($row_fp2->{t_double}->{value}, -0.000012345, "Check negative double value.");
is($row_fp2->{t_float}->{value}, -0.5, "Check negative float value.");
is($row_fp2->{t_decimal}->{value}, $float2_s,
    "Check negative decimal (arbitrary precision float) value.");


# Check integer types
my $varint_v = Math::BigInt->new("1000000000000000000001");
my $param_int = {
    biv => 8589934592,
    iv => 7,
    viv => $varint_v,
};
$res = $dbh->exec("INSERT INTO all_types (pk, t_bigint, t_int, t_varint) VALUES ('int_test1', :biv, :iv, :viv)", $param_int);
$res = $dbh->exec("SELECT pk, t_bigint, t_int, t_varint FROM all_types WHERE pk = 'int_test1'");
my $row_int1 = $res->fetchone();
is($row_int1->{t_bigint}->{value}, 8589934592, "Check bigint (64-bit int) value.");
is($row_int1->{t_int}->{value}, 7, "Check int (32-bit int) value.");
is($row_int1->{t_varint}->{value}, 
    "1000000000000000000001", "Check varint (arbitrary precision) value.");

my $varint_v2 = Math::BigInt->new("1000000000000000000001");
my $param_int2 = {
    biv => -8589934592,
    iv => -7,
    viv => $varint_v2,
};
$res = $dbh->exec("INSERT INTO all_types (pk, t_bigint, t_int, t_varint) VALUES ('int_test2', :biv, :iv, :viv)", $param_int2);
$res = $dbh->exec("SELECT pk, t_bigint, t_int, t_varint FROM all_types WHERE pk = 'int_test2'");
my $row_int2 = $res->fetchone();
is($row_int2->{t_bigint}->{value}, -8589934592, "Check negative bigint (64-bit int) value.");
is($row_int2->{t_int}->{value}, -7, "Check negative int (32-bit int) value.");
is($row_int2->{t_varint}->{value}, 
    "1000000000000000000001", "Check varint (arbitrary precision) value.");

# Still need to implement/fix and test
#    i_blob => 'v_blob',
#    i_inet => '10.9.8.7',
#    i_text => 'v_text',
#    i_timestamp => 'v_timestamp',
#    i_timeuuid => 'v_timeuuid',
#    i_uuid => 'v_uuid',
#    i_varchar => 'v_varchar',
# Collections and counters

# Working 
#    i_ascii => 'v_ascii',
#    i_bigint => 'v_bigint',
#    i_boolean => 1,
#    i_decimal => 'v_decimal',
#    i_double => 12.5,
#    i_float => 900.5
#    i_int => 'v_int',
#    i_varint => 'v_varint',

# Partial Support
#    i_text => 'v_text',
#    i_varchar => 'v_varchar',

$dbh->finish();    

