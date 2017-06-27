use warnings;
use strict;

package Log::Report::Minimal;
use base 'Exporter';

use Log::Report::Util;
use List::Util        qw/first/;
use Scalar::Util      qw/blessed/;

use Log::Report::Minimal::Domain ();

### if you change anything here, you also have to change Log::Report::Minimal
my @make_msg         = qw/__ __x __n __nx __xn N__ N__n N__w/;
my @functions        = qw/report dispatcher try textdomain/;
my @reason_functions = qw/trace assert info notice warning
   mistake error fault alert failure panic/;

our @EXPORT_OK = (@make_msg, @functions, @reason_functions);

sub trace(@); sub assert(@); sub info(@); sub notice(@); sub warning(@);
sub mistake(@); sub error(@); sub fault(@); sub alert(@); sub failure(@);
sub panic(@); sub report(@); sub textdomain($@);
sub __($); sub __x($@); sub __n($$$@); sub __nx($$$@); sub __xn($$$@);
sub N__($); sub N__n($$); sub N__w(@);

my ($mode, %need);
sub need($)
{   $mode = shift;
    %need = map +($_ => 1), expand_reasons mode_accepts $mode;
}
need 'NORMAL';

my %textdomains;
textdomain 'default';

sub _interpolate(@)
{   my ($msgid, %args) = @_;

    my $textdomain = $args{_domain};
    unless($textdomain)
    {   my ($pkg) = caller 1;
        $textdomain = pkg2domain $pkg;
    }

    (textdomain $textdomain)->interpolate($msgid, \%args);
}

#
# Some initiations
#

=chapter NAME
Log::Report::Minimal - simulate Log::Report functions simple

=chapter SYNOPSIS
 # See Log::Report, most functions get "hollow" behavior
 use Log::Report::Optional mode => 'DEBUG';

=chapter DESCRIPTION 

This module implements the functions provided by M<Log::Report>, but then
as simple as possible: no support for translations, no dispatchers, no
smart exceptions.  The package uses C<Log::Report> in an C<::Optional>
way, the main script determines whether it wants the C<::Minimal> or
full-blown feature set.

=chapter FUNCTIONS

=function textdomain <[$name],$config>|<$name, 'DELETE'|'EXISTS'>|$domain

=cut

sub textdomain($@)
{   if(@_==1 && blessed $_[0])
    {   my $domain = shift;
        return $textdomains{$domain->name} = $domain;
    }

    if(@_==2)
    {    # used for 'maintenance' and testing
        return delete $textdomains{$_[0]} if $_[1] eq 'DELETE';
        return $textdomains{$_[0]} if $_[1] eq 'EXISTS';
    }

    my $name   = shift;
    my $domain = $textdomains{$name}
      ||= Log::Report::Minimal::Domain->new(name => $name);

    @_ ? $domain->configure(@_, where => [caller]) : $domain;
}

=section Report Production and Configuration

=function report [$options], $reason, $message|<STRING,$params>
Be warned that %options is a HASH here.

=option  errno INTEGER
=default errno C<$!> or C<1>

=option  is_fatal BOOLEAN
=default is_fatal <depends on reason>
 
=cut

# $^S = $EXCEPTIONS_BEING_CAUGHT; parse: undef, eval: 1, else 0

sub _report($$@)
{   my ($opts, $reason) = (shift, shift);

    # return when no-one needs it: skip unused trace() fast!
    my $stop = exists $opts->{is_fatal} ? $opts->{is_fatal} : is_fatal $reason;
    $need{$reason} || $stop or return;

    is_reason $reason
        or error __x"token '{token}' not recognized as reason", token=>$reason;

    $opts->{errno} ||= $!+0 || $? || 1
        if use_errno($reason) && !defined $opts->{errno};

    my $message = shift;
    @_%2 and error __x"odd length parameter list with '{msg}'", msg => $message;

    my $show    = lc($reason).': '.$message;

    if($stop)
    {   # ^S = EXCEPTIONS_BEING_CAUGHT, within eval or try
        $! = $opts->{errno} || 0;
        die "$show\n";    # call the die handler
    }
    else
    {   warn "$show\n";   # call the warn handler
    }

    1;
}

=function dispatcher <$type, $name, %options>|<$command, @names>
Not supported.
=cut

sub dispatcher($@) { panic "no dispatchers available in ".__PACKAGE__ }

=function try CODE, %options
=cut

sub try(&@)
{   my $code = shift;

    @_ % 2 and report {}, PANIC =>
        __x"odd length parameter list for try(): forgot the terminating ';'?";

#XXX MO: only needs the fatal subset, exclude the warns/prints

    eval { $code->() };
}

=section Abbreviations for report()
=function trace $message
=function assert $message
=function info $message
=function notice $message
=function warning $message
=function mistake $message
=function error $message
=function fault $message
=function alert $message
=function failure $message
=function panic $message
=cut

sub report(@)
{   my %opt = @_ && ref $_[0] eq 'HASH' ? %{ (shift) } : ();
    _report \%opt, @_;
}

sub trace(@)   {_report {}, TRACE   => @_}
sub assert(@)  {_report {}, ASSERT  => @_}
sub info(@)    {_report {}, INFO    => @_}
sub notice(@)  {_report {}, NOTICE  => @_}
sub warning(@) {_report {}, WARNING => @_}
sub mistake(@) {_report {}, MISTAKE => @_}
sub error(@)   {_report {}, ERROR   => @_}
sub fault(@)   {_report {}, FAULT   => @_}
sub alert(@)   {_report {}, ALERT   => @_}
sub failure(@) {_report {}, FAILURE => @_}
sub panic(@)   {_report {}, PANIC   => @_}

=section Language Translations

No translations, no L<Log::Report::Message> objects returned.

=function __ $msgid
=cut

sub __($) { shift }

=function __x $msgid, PAIRS
=cut

sub __x($@)
{   @_%2 or error __x"even length parameter list for __x at {where}"
      , where => join(' line ', (caller)[1,2]);

    _interpolate @_, _expand => 1;
} 

=function __n $msgid, $plural_msgid, $count, PAIRS
=cut

sub __n($$$@)
{   my ($single, $plural, $count) = (shift, shift, shift);
    _interpolate +($count==1 ? $single : $plural)
      , _count => $count, @_;
}

=function __nx $msgid, $plural_msgid, $count, PAIRS
=cut

sub __nx($$$@)
{   my ($single, $plural, $count) = (shift, shift, shift);
    _interpolate +($count==1 ? $single : $plural)
      , _count => $count, _expand => 1, @_;
}

=function __xn $single_msgid, $plural_msgid, $count, PAIRS
=cut

sub __xn($$$@)   # repeated for prototype
{   my ($single, $plural, $count) = (shift, shift, shift);
    _interpolate +($count==1 ? $single : $plural)
      , _count => $count , _expand => 1, @_;
}

=function N__ $msgid
=function N__n $single_msgid, $plural_msgid
=function N__w STRING
=cut

sub N__($)   { $_[0] }
sub N__n($$) {@_}
sub N__w(@)  {split " ", $_[0]}

#------------------
=section Configuration

=method import [$domain], %options
See M<Log::Report::import()>.
=cut

sub import(@)
{   my $class = shift;

    my $to_level   = @_ && $_[0] =~ m/^\+\d+$/ ? shift : 0;
    my $textdomain = @_%2 ? shift : 'default';
    my %opts       = @_;
    my $syntax     = delete $opts{syntax} || 'SHORT';

    my ($pkg, $fn, $linenr) = caller $to_level;
    pkg2domain $pkg, $textdomain, $fn, $linenr;
    my $domain     = textdomain $textdomain;

    need delete $opts{mode}
        if defined $opts{mode};

    my @export;
    if(my $in = $opts{import})
    {   push @export, ref $in eq 'ARRAY' ? @$in : $in;
    }
    else
    {   push @export, @functions, @make_msg;

        my $syntax = delete $opts{syntax} || 'SHORT';
        if($syntax eq 'SHORT')
        {   push @export, @reason_functions
        }
        elsif($syntax ne 'REPORT' && $syntax ne 'LONG')
        {   error __x"syntax flag must be either SHORT or REPORT, not `{flag}'"
              , flag => $syntax;
        }
    }

    $class->export_to_level(1+$to_level, undef, @export);

    $domain->configure(%opts, where => [$pkg, $fn, $linenr ])
        if %opts;
}

1;
