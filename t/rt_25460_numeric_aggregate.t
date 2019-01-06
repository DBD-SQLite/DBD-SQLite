use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

# Create the table
my $dbh = connect_ok();
ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE' );
create table foo (
	id integer primary key not null,
	mygroup varchar(255) not null,
	mynumber numeric(20,3) not null
)
END_SQL

# Fill the table
my @data = qw{
	a -2
	a 1
	b 2
	b 1
	c 3
	c -1
	d 4
	d 5
	e 6
	e 7
};
$dbh->begin_work;
while ( @data ) {
	ok $dbh->do(
		'insert into foo ( mygroup, mynumber ) values ( ?, ? )', {},
		shift(@data), shift(@data),
	);
}
$dbh->commit;

# Issue the group/sum/sort/limit query
my $rv = $dbh->selectall_arrayref(<<'END_SQL');
select mygroup, sum(mynumber) as total
from foo
group by mygroup
order by total
limit 3
END_SQL

is_deeply(
	$rv,
	[
		[ 'a', -1 ],
		[ 'c', 2  ],
		[ 'b', 3  ], 
	],
	'group/sum/sort/limit query ok'
);

done_testing;
