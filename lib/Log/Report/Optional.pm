#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Log::Report::Optional;
use base 'Exporter';

use warnings;
use strict;

#--------------------
=chapter NAME
Log::Report::Optional - pick Log::Report or ::Minimal

=chapter SYNOPSIS
  # Use Log::Report when already loaded, otherwise Log::Report::Minimal
  package My::Package;
  use Log::Report::Optional 'my-domain';

=chapter DESCRIPTION
This module will allow libraries (helper modules) to have a dependency
to a small module instead of the full Log-Report distribution.  The full
power of C<Log::Report> is only released when the main program uses that
module.  In that case, the module using the 'Optional' will also use the
full Log::Report, otherwise the dressed-down Log::Report::Minimal
version.

For the full documentation:

=over 4
=item * see Log::Report when it is used by main
=item * see Log::Report::Minimal otherwise
=back

The latter provides the same functions from the former, but is the
simpelest possible way.

=cut

my ($supported, @used_by);

BEGIN {
	if($INC{'Log/Report.pm'})
	{	$supported  = 'Log::Report';
		my $version = $Log::Report::VERSION;
		die "Log::Report too old for ::Optional, need at least 1.00"
			if $version && $version le '1.00';
	}
	else
	{	require Log::Report::Minimal;
		$supported = 'Log::Report::Minimal';
	}
}

sub import(@)
{	my $class = shift;
	push @used_by, (caller)[0];
	$supported->import('+1', @_);
}

#--------------------
=chapter METHODS

=c_method usedBy
Returns the classes which loaded the optional module.
=cut

sub usedBy() { @used_by }

1;
