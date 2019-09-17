package DNS::Zone::Struct::To::BIND;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(
                       gen_bind_zone_from_struct
               );

our %SPEC;

# find first record with specified type
sub _find_rec_by_time {
    my ($recs, $type) = @_;
    for (@$recs) {
        return $_ if $_->{type} eq $type;
    }
    undef;
}

sub _abs_host {
    my $host = shift;
    $host eq '' ? '@' : $host =~ /\.\z/ ? $host : "$host.";
}

sub _encode_email_as_name {
    my $email = shift;
    my ($before, $after) = split /\@/, $email, 2;
    $before =~ s/\./\\./g;
    "$before." . _abs_host($after);
}

# XXX
sub _encode_txt {
    my $text = shift;
    qq("$text");
}

$SPEC{gen_bind_zone_from_struct} = {
    v => 1.1,
    summary => 'Generate BIND zone configuration from structure',
    args => {
        zone => {
            schema => ['dns::zone*'],
            description => <<'_',

DNS zone structure, as described in the `dns::zone` Sah schema (see
<pm:Sah::Schema::dns::zone>).

_
            req => 1,
        },
        master_host => {
            schema => ['net::hostname*'],
            req => 1,
        },
    },
    result_naked => 1,
};
sub gen_bind_zone_from_struct {
    my %args = @_;
    my $zone = $args{zone};

    my @res;

    {
        my $rec = _find_rec_by_time($zone->{records}, 'SOA');
        push @res, '$TTL ', $rec->{ttl}, "\n";
        push @res, "\@ IN $rec->{ttl} SOA ", _abs_host($args{master_host}), " ", _encode_email_as_name($rec->{email}), " (\n";
        push @res, "  $rec->{serial} ;serial\n";
        push @res, "  $rec->{refresh} ;refresh\n";
        push @res, "  $rec->{retry} ;retry\n";
        push @res, "  $rec->{expire} ;expire\n";
        push @res, "  $rec->{ttl} ;ttl\n";
        push @res, "  )\n";
    }

    for my $rec (@{ $zone->{records} }) {
        my $type = $rec->{type};
        next if $type eq 'SOA';
        push @res, "$rec->{name} ", ($rec->{ttl} ? "$rec->{ttl} ":""), "IN ";
        if ($type eq 'A') {
            push @res, "A $rec->{address}\n";
        } elsif ($type eq 'CNAME') {
            push @res, "CNAME ", _abs_host($rec->{canon}), "\n";
        } elsif ($type eq 'MX') {
            push @res, "MX $rec->{priority} ", $rec->{host}, "\n";
        } elsif ($type eq 'NS') {
            push @res, "NS ", _abs_host($rec->{host}), "\n";
        } elsif ($type eq 'SRV') {
            push @res, "SRV $rec->{prio} $rec->{weight} $rec->{port} $rec->{target}\n";
        } elsif ($type eq 'SSHFP') {
            push @res, "SSHFP $rec->{algo} $rec->{fptype} $rec->{fp}\n";
        } elsif ($type eq 'TXT') {
            push @res, "TXT ", _encode_txt($rec->{text}), "\n";
        } else {
            die "Can't dump record with type $type";
        }
    }

    join "", @res;
}

1;
# ABSTRACT:

=head1 SYNOPSIS

 use DNS::Zone::Struct::To::BIND qw(gen_bind_zone_from_struct);

 say gen_bind_zone_from_struct(
     zone => {
         records => [
             {type=>'SOA',   name=>'', host=>'', ttl=>300, serial=>'2019072401', refresh=>7200, retry=>1800, expire=>12009600, email=>'hostmaster@example.org'},
             {type=>'NS',    name=>'', host=>'ns1.example.com'},
             {type=>'NS',    name=>'', host=>'ns2.example.com'},
             {type=>'A' ,    name=>'', address=>'1.2.3.4'},
             {type=>'CNAME', name=>'www', canon=>''},
         ],
     },
     master_host => 'ns1.example.com',
 );

will output something like:

 $TTL 300
 @ IN 300 SOA ns1.example.com. hostmaster.example.org. (
   2019072401 ;serial
   7200 ;refresh
   1800 ;retry
   12009600 ;expire
   300 ;ttl
   )
  IN NS ns1.example.com.
  IN NS ns2.example.com.
  IN A 1.2.3.4
 www IN CNAME @


=head1 SEE ALSO

L<Sah::Schemas::DNS>
