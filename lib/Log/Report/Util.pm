
use warnings;
use strict;

package Log::Report::Util;
use base 'Exporter';

use String::Print qw(printi);

our @EXPORT = qw/
  @reasons is_reason is_fatal use_errno
  mode_number expand_reasons mode_accepts
  must_show_location must_show_stack
  escape_chars unescape_chars
  parse_locale
  pkg2domain
 /;
# [0.994 parse_locale deprecated, but kept hidden]

our @EXPORT_OK = qw/%reason_code/;

#use Log::Report 'log-report';
sub N__w($) { split ' ', $_[0] }

# ordered!
our @reasons  = N__w('TRACE ASSERT INFO NOTICE WARNING
    MISTAKE ERROR FAULT ALERT FAILURE PANIC');
our %reason_code; { my $i=1; %reason_code = map +($_ => $i++), @reasons }

my @user      = qw/MISTAKE ERROR/;
my @program   = qw/TRACE ASSERT INFO NOTICE WARNING PANIC/;
my @system    = qw/FAULT ALERT FAILURE/;

my %is_fatal  = map +($_=>1), qw/ERROR FAULT FAILURE PANIC/;
my %use_errno = map +($_=>1), qw/FAULT ALERT FAILURE/;

my %modes     = (NORMAL => 0, VERBOSE => 1, ASSERT => 2, DEBUG => 3
  , 0 => 0, 1 => 1, 2 => 2, 3 => 3);
my @mode_accepts = ('NOTICE-', 'INFO-', 'ASSERT-', 'ALL');

=chapter NAME
Log::Report::Util - helpful routines to Log::Report

=chapter SYNOPSYS
 my ($language, $territory, $charset, $modifier)
    = parse_locale 'nl_BE.utf-8@home';

 my @take = expand_reasons 'INFO-ERROR,PANIC';

=chapter DESCRIPTION
This module collects a few functions and definitions which are shared
between different components in the M<Log::Report> infrastructure.
They should not be needed for end-user applications, although this
man-page may contain some useful background information.

=chapter FUNCTIONS

=section Reasons

=function expand_reasons REASONS
Returns a sub-set of all existing message reason labels, based on the
content REASONS string. The following rules apply:
 REASONS = BLOCK [ ',' BLOCKS]
 BLOCK   = '-' TO | FROM '-' TO | ONE | SOURCE
 FROM,TO,ONE = 'TRACE' | 'ASSERT' | ,,, | 'PANIC'
 SOURCE  = 'USER' | 'PROGRAM' | 'SYSTEM' | 'ALL'

The SOURCE specification group all reasons which are usually related to
the problem: report about problems caused by the user, reported by
the program, or with system interaction.

=examples of expended REASONS
 WARNING-FAULT # == WARNING,MISTAKE,ERROR,FAULT
 -INFO         # == TRACE-INFO
 ALERT-        # == ALERT,FAILURE,PANIC
 USER          # == MISTAKE,ERROR
 ALL           # == TRACE-PANIC
=cut

sub expand_reasons($)
{   my $reasons = shift;
    my %r;
    foreach my $r (split m/\,/, $reasons)
    {   if($r =~ m/^([a-z]*)\-([a-z]*)/i )
        {   my $begin = $reason_code{$1 || 'TRACE'};
            my $end   = $reason_code{$2 || 'PANIC'};
            $begin && $end
                or error __x "unknown reason {which} in '{reasons}'"
                     , which => ($begin ? $2 : $1), reasons => $reasons;

            error __x"reason '{begin}' more serious than '{end}' in '{reasons}"
              , begin => $1, end => $2, reasons => $reasons
                 if $begin >= $end;

            $r{$_}++ for $begin..$end;
        }
        elsif($reason_code{$r}) { $r{$reason_code{$r}}++ }
        elsif($r eq 'USER')     { $r{$reason_code{$_}}++ for @user    }
        elsif($r eq 'PROGRAM')  { $r{$reason_code{$_}}++ for @program }
        elsif($r eq 'SYSTEM')   { $r{$reason_code{$_}}++ for @system  }
        elsif($r eq 'ALL')      { $r{$reason_code{$_}}++ for @reasons }
        else
        {   error __x"unknown reason {which} in '{reasons}'"
              , which => $r, reasons => $reasons;
        }
    }
    (undef, @reasons)[sort {$a <=> $b} keys %r];
}

=function is_reason NAME
Returns true if the STRING is one of the predefined REASONS.

=function is_fatal REASON
Returns true if the REASON is severe enough to cause an exception
(or program termination).

=function use_errno REASON
=cut

sub is_reason($) { $reason_code{$_[0]} }
sub is_fatal($)  { $is_fatal{$_[0]}    }
sub use_errno($) { $use_errno{$_[0]}   }

#--------------------------
=section Modes
Run-modes are explained in M<Log::Report::Dispatcher>.

=function mode_number NAME|MODE
Returns the MODE as number.
=cut

sub mode_number($)  { $modes{$_[0]} }

=function mode_accepts MODE
Returns something acceptable by M<expand_reasons()>
=cut

sub mode_accepts($) { $mode_accepts[$modes{$_[0]}] }

=function must_show_location MODE, REASON
=cut

sub must_show_location($$)
{   my ($mode, $reason) = @_;
       $reason eq 'ASSERT'
    || $reason eq 'PANIC'
    || ($mode==2 && $reason_code{$reason} >= $reason_code{WARNING})
    || ($mode==3 && $reason_code{$reason} >= $reason_code{MISTAKE});
}

=function must_show_stack MODE, REASON
=cut

sub must_show_stack($$)
{   my ($mode, $reason) = @_;
        $reason eq 'PANIC'
     || ($mode==2 && $reason_code{$reason} >= $reason_code{ALERT})
     || ($mode==3 && $reason_code{$reason} >= $reason_code{ERROR});
}

#-------------------------
=section Other

=function escape_chars STRING
Replace all escape characters into their readable counterpart.  For
instance, a new-line is replaced by backslash-n.

=function unescape_chars STRING
Replace all backslash-something escapes by their escape character.
For instance, backslash-t is replaced by a tab character.
=cut

my %unescape =
  ( '\a' => "\a", '\b' => "\b", '\f' => "\f", '\n' => "\n"
  , '\r' => "\r", '\t' => "\t", '\"' => '"', '\\\\' => '\\'
  , '\e' =>  "\x1b", '\v' => "\x0b"
  );
my %escape   = reverse %unescape;

sub escape_chars($)
{   my $str = shift;
    $str =~ s/([\x00-\x1F"\\])/$escape{$1} || '?'/ge;
    $str;
}

sub unescape_chars($)
{   my $str = shift;
    $str =~ s/(\\.)/$unescape{$1} || $1/ge;
    $str;
}

=function parse_locale STRING
Decompose a locale string.

For simplicity of the caller's code, the capatization of the returned
fields is standardized to the preferred, although the match is case-
insensitive as required by the RFC. The territory in returned in capitals
(ISO3166), the language is lower-case (ISO639), the script as upper-case
first, the character-set as lower-case, and the modifier and variant unchanged.

In LIST context, four elements are returned: language, territory,
character-set (codeset), and modifier.  Those four are important for the
usual unix translationg infrastructure.  Only the "country" is obligatory,
the others can be C<undef>.  It may also return C<C> and C<POSIX>.

In SCALAR context, a HASH is returned which can contain more information:
language, script, territory, variant, codeset, and modifiers.  The
variant (RFC3066 is probably never used)

=cut

sub parse_locale($)
{   my $locale = shift;
    defined $locale && length $locale
        or return;

    if($locale !~
      m/^ ([a-z_]+)
          (?: \. ([\w-]+) )?  # codeset
          (?: \@ (\S+) )?     # modifier
        $/ix)
    {   # Windows Finnish_Finland.1252?
        $locale =~ s/.*\.//;
        return wantarray ? ($locale) : { language => $locale };
    }

    my ($lang, $codeset, $modifier) = ($1, $2, $3);

    my @subtags  = split /[_-]/, $lang;
    my $primary  = lc shift @subtags;

    my $language
      = $primary eq 'c'             ? 'C'
      : $primary eq 'posix'         ? 'POSIX'
      : $primary =~ m/^[a-z]{2,3}$/ ? $primary            # ISO639-1 and -2
      : $primary eq 'i' && @subtags ? lc(shift @subtags)  # IANA
      : $primary eq 'x' && @subtags ? lc(shift @subtags)  # Private
      : error __x"unknown locale language in locale `{locale}'"
           , locale => $locale;

    my $script;
    $script = ucfirst lc shift @subtags
        if @subtags > 1 && length $subtags[0] > 3;

    my $territory = @subtags ? uc(shift @subtags) : undef;

    return ($language, $territory, $codeset, $modifier)
        if wantarray;

    +{ language  => $language
     , script    => $script
     , territory => $territory
     , codeset   => $codeset
     , modifier  => $modifier
     , variant   => join('-', @subtags)
     };
}

=function pkg2domain PACKAGE, [DOMAIN, FILENAME, LINE]
With DOMAIN, FILENAME and LINE, this registers a location where the
textdomain is specified.  Each PACKAGE can only belong to one DOMAIN.

Without these parameters, the registered domain for the PACKAGE is
returned.
=cut

my %pkg2domain;
sub pkg2domain($;$$$)
{   my $pkg = shift;
    my $d   = $pkg2domain{$pkg};
    @_ or return $d ? $d->[0] : 'default';

    my ($domain, $fn, $line) = @_;
    if($d)
    {   # registration already exists
        return $domain if $d->[0] eq $domain;
        printi "conflict: package {pkg} in {domain1} in {file1} line {line1}, but in {domain2} in {file2} line {line2}"
           , pkg => $pkg
           , domain1 => $domain, file1 => $fn, line1 => $line
           , domain2 => $d->[0], file2 => $d->[1], line2 => $d->[2];
    }

    # new registration
    $pkg2domain{$pkg} = [$domain, $fn, $line];
    $domain;
}

1;
