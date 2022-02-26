use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

BEGIN {
	if (!has_compile_option('ENABLE_COLUMN_METADATA')) {
		plan skip_all => "Column metadata is disabled for this DBD::SQLite";
	}
}

for my $call_func (@CALL_FUNCS) {
	my $dbh = connect_ok(RaiseError => 1);
	$dbh->do('create table foo (id integer primary key autoincrement, "name space", unique_col integer unique)');

	{
		my $data = $dbh->$call_func(undef, 'foo', 'id', 'table_column_metadata');
		ok $data && ref $data eq ref {}, "got a metadata";
		ok $data->{auto_increment}, "id is auto incremental";
		is $data->{data_type} => 'integer', "data type is correct";
		ok $data->{primary}, "id is a primary key";
		ok !$data->{not_null}, "id is not null";
	}

	{
		my $data = $dbh->$call_func(undef, 'foo', 'name space', 'table_column_metadata');
		ok $data && ref $data eq ref {}, "got a metadata";
		ok !$data->{auto_increment}, "name space is not auto incremental";
		is $data->{data_type} => undef, "data type is not defined";
		ok !$data->{primary}, "name space is not a primary key";
		ok !$data->{not_null}, "name space is not null";
	}

	# exceptions
	{
		local $SIG{__WARN__} = sub {};
		eval { $dbh->$call_func(undef, undef, 'name space', 'table_column_metadata') };
		ok $@, "successfully died when tablename is undef";

		eval { $dbh->$call_func(undef, '', 'name space', 'table_column_metadata') };
		ok !$@, "not died when tablename is an empty string";

		eval { $dbh->$call_func(undef, 'foo', undef, 'table_column_metadata') };
		ok $@, "successfully died when columnname is undef";

		eval { $dbh->$call_func(undef, 'foo', '', 'table_column_metadata') };
		ok !$@, "not died when columnname is an empty string";

		$dbh->disconnect;

		eval { $dbh->$call_func(undef, 'foo', 'name space', 'table_column_metadata') };
		ok $@, "successfully died when dbh is inactive";
	}
}

done_testing;
