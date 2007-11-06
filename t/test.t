#!perl -wT

# ~~~ TO DO: write tests for tied IO refs and hash/array elements
# I also need to write a test to make sure that blessed overload methods(!)
# don't mess up the check in _underload (defined overload::Method...). I
# need to make sure someone doesn't remove that 'defined' in future and
# cause it to stop working.

use Test::More tests =>
	+1  # use
	+8  # tie to
	+9  # is_tied
	+8  # weak_tie
	+4  # is_tied again (stale ties)
	+10 # weaken_tie
	+20 # is_weak_tie
;

BEGIN { use_ok 'Tie::Util' };

no warnings 'once';

{ package overloaded;
	use overload fallback => 1,
	'${}' => sub { \my $v },
	'@{}' => sub { [] },
	'%{}' => sub { +{} },
	'&{}' => sub { my $v; sub { $v } },
	'*{}' => sub { \*oeutnhnoetunhnt },
	 bool => sub{0};
	*TIESCALAR = *TIEHASH = *TIEARRAY = *TIEHANDLE =
	sub { bless $_[1] };
}

bless $_, 'overloaded' for \($~,@~,%~,*~,$%,@%,%%,*%,);
# makes it harder for the functions to get at the tied variable

*TIESCALAR = *TIEHASH = *TIEARRAY = *TIEHANDLE =
	sub { bless $_[1] };

sub UNTIE { ++$untied };

my $obj = bless[];
is tie($~, to => $obj), $obj, 'return value of tie$to';
is tie(@~, to => $obj), $obj, 'return value of tie@to';
is tie(%~, to => $obj), $obj, 'return value of tie%to';
is tie(*~, to => $obj), $obj, 'return value of tie*to';
is tied($~), $obj, 'tie$to works';
is tied(@~), $obj, 'tie@to works';
is tied(%~), $obj, 'tie%to works';
is tied(*~), $obj, 'tie*to works';

# These lines were making is_tied return true for @% and %%, until
# I fixed it:
tie $%[0], to => $obj;
tie $%{0}, to => $obj;

is is_tied($~), 1, 'is_tied$';
is is_tied(@~), 1, 'is_tied@';
is is_tied(%~), 1, 'is_tied%';
is is_tied(*~), 1, 'is_tied*';
is is_tied($%), '', '!is_tied$';
is is_tied(@%), '', '!is_tied@';
is is_tied(%%), '', '!is_tied%';
is is_tied(*%), '', '!is_tied*';
tie @%, overloaded, bless[],overloaded;
ok is_tied(@%), 'is_tied @tied_to_bool_false_obj';

{	my $foo = bless[0];
	untie($~), untie(@~), untie(%~), untie(*~);
	weak_tie $~, '', $foo;
	weak_tie @~, '', $foo;
	weak_tie %~, '', $foo;
	weak_tie *~, '', $foo;
	is tied($~), $foo, 'weak_tie$';
	is tied(@~), $foo, 'weak_tie@';
	is tied(%~), $foo, 'weak_tie%';
	is tied(*~), $foo, 'weak_tie*'; }
is tied($~), undef, 'weak_tie$ gone stale';
is tied(@~), undef, 'weak_tie@ gone stale';
is tied(%~), undef, 'weak_tie% gone stale';
is tied(*~), undef, 'weak_tie* gone stale';

is is_tied($~), 1, 'is_tied $stale_tie';
is is_tied(@~), 1, 'is_tied @stale_tie';
is is_tied(%~), 1, 'is_tied %stale_tie';
is is_tied(*~), 1, 'is_tied *stale_tie';

untie($~), untie(@~), untie(%~), untie(*~);
$untied = 0; # weaken_tie has to clobber the UNTIE method temporarily in
             # the package into which the object to which the variable is
             # tied is blessed.
{	my $foo = bless[0];
	tie $~, '', $foo;
	tie @~, '', $foo; # strong
	tie %~, '', $foo; # ties
	tie *~, '', $foo;
	weaken_tie $~;    # not
	weaken_tie @~;    # any
	weaken_tie %~;    # more
	weaken_tie *~;
	is tied($~), $foo, 'weaken_tie$ before staleness';
	is tied(@~), $foo, 'weaken_tie@ before staleness';
	is tied(%~), $foo, 'weaken_tie% before staleness';
	is tied(*~), $foo, 'weaken_tie* before staleness'; }
is tied($~), undef, 'weaken_tie$ gone stale and mouldy';
is tied(@~), undef, 'weaken_tie@ gone stale';
is tied(%~), undef, 'weaken_tie% gone stale';
is tied(*~), undef, 'weaken_tie* stalemate';
is $untied, 0, 'UNTIE is not called inadvertently';
ok defined &UNTIE, 'UNTIE was not inadvertently deleted';

{	my $foo = bless[0];
	untie($~), untie(@~), untie(%~), untie(*~);
	tie $~, '', $foo;
	tie @~, '', $foo; # strong
	tie %~, '', $foo; # ties
	tie *~, '', $foo;
	is is_weak_tie($~), '', 'is_weak_tie$ with strong tie';
	is is_weak_tie(@~), '', 'is_weak_tie@ with strong tie';
	is is_weak_tie(%~), '', 'is_weak_tie% with strong tie';
	is is_weak_tie(*~), '', 'is_weak_tie* with strong tie';
	weaken_tie $~;    # not
	weaken_tie @~;    # any
	weaken_tie %~;    # more
	weaken_tie *~;
	is is_weak_tie($~), 1, 'is_weak_tie$ with weak tie';
	is is_weak_tie(@~), 1, 'is_weak_tie@ with weak tie';
	is is_weak_tie(%~), 1, 'is_weak_tie% with weak tie';
	is is_weak_tie(*~), 1, 'is_weak_tie* with weak tie';
	is tied($~), $foo, 'weaken_tie$ before staleness';
	is tied(@~), $foo, 'weaken_tie@ before staleness';
	is tied(%~), $foo, 'weaken_tie% before staleness';
	is tied(*~), $foo, 'weaken_tie* before staleness'; }
is is_weak_tie($~), 1, 'is_weak_tie$ with stale tie';
is is_weak_tie(@~), 1, 'is_weak_tie@ with stale tie';
is is_weak_tie(%~), 1, 'is_weak_tie% with stale tie';
is is_weak_tie(*~), 1, 'is_weak_tie* with stale tie';
is is_weak_tie($^), undef, 'is_weak_tie$ with no tie';
is is_weak_tie(@^), undef, 'is_weak_tie@ with no tie';
is is_weak_tie(%^), undef, 'is_weak_tie% with no tie';
is is_weak_tie(*^), undef, 'is_weak_tie* with no tie';

