package Tie::Util;

use 5.006;

$VERSION = '0.01';

# B doesn't export this. I *hope* it doesn't change!
use constant SVprv_WEAKREF => 0x80000000; # from sv.h

use Exporter 5.57 'import';
use Scalar::Util qw 'reftype blessed weaken';

@EXPORT = qw 'is_tied weak_tie weaken_tie is_weak_tie';
%EXPORT_TAGS = (all=>\@EXPORT);

{
	my ($ref, $class);
	sub _underload($) {
		$ref = shift;
		my $type = reftype $ref;
		# This assumes that no one is overloading without loading
		# overload.pm.  I suppose I could  change  this  to  call
		# UNIVERSAL::can($ref, "($sigil\{}") (at the risk of trig-
		# ering  negative  reactions  from  OO-purists  perusing
		# this code :-).
		if(defined blessed $ref && $INC{'overload.pm'}) {
			my $sigil = $type eq 'GLOB' || $type eq 'IO' ? '*'
			           :$type eq 'HASH'                  ? '%'
			           :$type eq 'ARRAY'                 ? '@'
			           :                                   '$';
			if(defined overload::Method($ref,"$sigil\{}")) {
				$class = ref $ref;
				bless $ref;
			}
		}
		return $ref;
	}
	sub _restore() {
		defined $class and bless $ref, $class;
		undef $ref, undef $class
	}
}

sub expand($) {
	local *_ = \do{my $x = shift};
	my $done_type;
	s<<<<(.*?)>>>><
		my $code = $1;
		my $type_decl = '';
		unless($done_type++) {
			$code =~ /\*(?:(\$\w+)|\{(.*?)})/;
			$type_decl = "my \$type = reftype " . ($1||$2);
		}
		my $subst = "
			$type_decl;
			if(\$type eq 'GLOB' || \$type eq 'IO') {
				$code
			} elsif(\$type eq 'HASH') {
		";
		(my $copy = $code) =~ y @*@%@;
		$subst .= qq!
				$copy
			} elsif(\$type eq 'ARRAY') {
		!;
		($copy = $code) =~ y ~*~@~;
		$subst .= "
				$copy
			} else {
		";
		$code =~ y&*&$&;
		"$subst$code}";
	>gse;
	eval "$_}";
#warn $_;
}

# This is what I first intended, but I realised that a to:: package allowed
# a weak tie as well, without requiring Yet Another function.
#expand<<'}';
#sub tie_to (\[%$@*]$) {
#	my ($var, $obj) = @_;
#	my $class = _underload $var;
#	<<<tie *$var, __PACKAGE__, $obj;>>>
#	_restore;
#	$obj
#}

#*TIEARRAY = *TIESCALAR = *TIEHANDLE = *TIEHASH = sub { $_[1] };
*to'TIEARRAY = *to'TIESCALAR = *to'TIEHANDLE = *to'TIEHASH = sub { $_[1] };

expand<<'}';
sub is_tied (\[%$@*]) {
	my ($var) = @_;
	my $class = _underload $var;
	<<<defined tied *$var and _restore, return !0;>>>
        # If tied returns undef, it might still be tied, in which case all
	# tie methods will die.
	local $@;
	eval {
		if( $type eq 'GLOB' || $type eq 'IO' ){
			no warnings 'unopened';
			()= tell $var
		} elsif($type eq 'HASH') {
			#()= %$var # We can't use this, because it might
			           # be an untied hash with a stale tied
			           # element, and we could get a
			           # false positive.
			()= scalar keys %$var
		} elsif($type eq 'ARRAY') {
			#()= @$var # same here
			()= $#$var;
		} else {
			()= $$var
		}
	};
	_restore;
	return !!$@;
}

expand<<'}';
sub weak_tie(\[%@$*]$@){
	my($var,$class,@args) = @_; _underload $var;
	<<<weaken tie *$var, $class, @args;>>>
	_restore;
	<<<return tied *$var>>>
}

expand<<'}';
sub weaken_tie(\[%@$*]){
	my $var = _underload shift;
	my $obj;
	<<<$obj = tied *$var;>>>
	if(!defined $obj) {
		_restore, return
	}
	# I have to re-tie it, since 'weaken tied' doesn't work.
	local *{ref($obj).'::UNTIE'};
	<<<weaken tie *$var, to => $obj>>>;
	_restore, return;
}

expand<<'}';
sub is_weak_tie(\[%@$*]){
	return undef unless &is_tied($_[0]);
	_underload $_[0];
	<<<_restore,return 1 if not defined tied *{$_[0]};>>> # stale

	# We have to use B here because 'isweak tied' fails.

# From pp_sys.c in the perl source code:
#	    /* For tied filehandles, we apply tiedscalar magic to the IO
#	       slot of the GP rather than the GV itself. AMS 20010812 */
	my $thing = shift;
	$type eq 'GLOB' and $thing = *$thing{IO};
	_restore;

	exists & svref_2object or require(B), B->import('svref_2object');
	for(svref_2object($thing)->MAGIC) {
		$_->TYPE =~ /^[qPp]\z/ and
			return !!($_->OBJ->FLAGS & SVprv_WEAKREF);
	}
	die "Tie::Util internal error: This tied variable has no tie magic! Bug reports welcome.";
}

undef *expand;

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!()__END__()!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

=head1 NAME

Tie::Util - Utility functions for fiddling with tied variables

=head1 VERSION

Version 0.01

This is a beta version. If you could please test it and report any bugs
(via e-mail), I would be grateful.

=head1 SYNOPSIS

  use Tie::Util;
  
  use Tie::RefHash;
  tie %hash, 'Tie::RefHash';
  
  $obj = tied %hash;
  tie %another_hash, to => $obj; # two hashes now tied to the same object
  
  is_tied %hash; # returns true
  
  $obj = weak_tie %hash3, 'Tie::RefHash';
  # %hash3 now holds a weak reference to the Tie::RefHash object.
  
  weaken_tie %another_hash; # weaken an existing tie
  
  is_weak_tie %hash3; # returns true
  is_weak_tie %hash;  # returns false but defined
  is_weak_tie %hash4; # returns undef (not tied)


=head1 DESCRIPTION

This module provides a few subroutines for examining and modifying
tied variables, including those that hold weak references to the
objects to which they are tied (weak ties).

It also provides tie constructors in the C<to::> namespace, so that you can
tie variables to existing objects, like this:

  tie $var, to => $obj;
  weak_tie @var, to => $another_obj; # for a weak tie

=head1 FUNCTIONS

All the following functions are exported by default. You can choose to
import only a few, with C<use Tie::Util qw'is_tied weak_tie'>, or none at
all, with C<use Tie::Util()>.

=over 4

=item is_tied [*%@$]var

Similar to the built-in L<tied|perlfunc/tied> function, but it returns a
simple scalar.

With this function you don't have to worry about whether the object to 
which a variable is tied overloads its booleanness (like L<JE::Boolean>
I<et al.>), so you can simply write C<is_tied> instead
of C<defined tied>.

Furthermore, it will still return true if it is a weak tie that has gone
stale (the object to which it was tied [without holding a reference count]
has lost all other references, so the variable is now tied to C<undef>),
whereas C<tied> returns C<undef> in such cases.

=item weak_tie [*%@$]var, $package, @args

Like L<tie|perlfunc/tie>, this calls C<$package>'s tie constructor, passing
it the C<@args>, and ties the variable to the returned object. But the tie
that it creates is a weak one, i.e., the tied variable does not hold a
reference count on the object.

=item weaken_tie [*%@$]var

This turns an existing tie into a weak one.

=item is_weak_tie [*%@$]var

Returns a defined true or false, indicating whether a tied variable is
weakly tied. Returns C<undef> if the variable is not tied.

=back

=head1 PREREQUISITES

perl 5.8.3 or later

=head1 BUGS

To report bugs, please e-mail the author.

=head1 AUTHOR & COPYRIGHT

Copyright (C) 2007 Father Chrysostomos <sprout [at] cpan
[dot] org>

This program is free software; you may redistribute it and/or modify
it under the same terms as perl.

=head1 SEE ALSO

The L<tie|perlfunc/tie> and L<tied|perlfunc/tied> functions in the
L<perlfunc> man page.

The L<perltie> man page.

L<Scalar::Util>'s L<weaken|Scalar::Util/weaken> function

The L<B> module.

L<Data::Dumper::Streamer>, for which I wrote two of these functions.
