use warnings;
use strict;

package Log::Report::Minimal::Domain;

use String::Print        'oo';

=chapter NAME
Log::Report::Minimal::Domain - administer one text-domain

=chapter SYNOPSIS

 use Log::Report::Minimal::Domain;
 my $domain = Log::Report::Minimal::Domain->new(name => $name);

 # normal usage
 use Log::Report::Optional;       # or Log::Report itself
 my $domain = textdomain $name;   # find config
 textdomain $name, %configure;    # set config, only once.

=chapter DESCRIPTION 
Read L<Log::Report::Domain>.

=chapter METHODS

=section Constructors

=c_method new %options

=requires name STRING

=cut

sub new(@)  { my $class = shift; (bless {}, $class)->init({@_}) }
sub init($)
{   my ($self, $args) = @_;
    $self->{LRMD_name} = $args->{name} or Log::Report::panic();
    $self;
}

#----------------

=section Attributes

=method name
=method isConfigured
=cut

sub name() {shift->{LRMD_name}}
sub isConfigured() {shift->{LRMD_where}}

=method configure %options
=requires where ARRAY
Specifies the location of the configuration.  It is not allowed to
configure a domain on more than one location.
=cut

sub configure(%)
{   my ($self, %args) = @_;

    my $here = $args{where} || [caller];
    if(my $s = $self->{LRMD_where})
    {   my $domain = $self->name;
        die "only one package can contain configuration; for $domain already in $s->[0] in file $s->[1] line $s->[2].  Now also found at $here->[1] line $here->[2]\n";
    }
    my $where = $self->{LRMD_where} = $here;

    # documented in the super-class, the more useful man-page
    my $format = $args{formatter} || 'PRINTI';
    $format    = {} if $format eq 'PRINTI';

    if(ref $format eq 'HASH')
    {   my $class  = delete $format->{class}  || 'String::Print';
        my $method = delete $format->{method} || 'sprinti';
		my $sp     = $class->new(%$format);
        $self->{LRMD_format} = sub { $sp->$method(@_) };
    }
    elsif(ref $format eq 'CODE')
    {   $self->{LRMD_format} = $format;
    }
    else
    {   error __x"illegal formatter `{name}' at {fn} line {line}"
          , name => $format, fn => $where->[1], line => $where->[2];
    }

    $self;
}

#-------------------
=section Action

=method interpolate $msgid, [$args]

Interpolate the keys used in C<$msgid> from the values in C<$args>.
This is handled by the formatter, by default a M<String::Print>
instance.

=cut

sub interpolate(@)
{   my ($self, $msgid, $args) = @_;
    $args->{_expand} or return $msgid;
    my $f = $self->{LRMD_format} || $self->configure->{LRMD_format};
    $f->($msgid, $args);
}

1;
