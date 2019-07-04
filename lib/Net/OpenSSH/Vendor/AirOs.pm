package Net::OpenSSH::Vendor::AirOs;

use Moose;
use namespace::autoclean;

use Net::OpenSSH;
use JSON::MaybeXS;

#extends 'Net::OpenSSH';

# ABSTRACT: Connect via SSH to Ubiquiti AirOs system like its radios

has ip          => (is => 'rw', required => 1, isa => 'Str');
has username    => (is => 'rw', required => 1, isa => 'Str');
has password    => (is => 'rw', required => 1, isa => 'Str');
has params      => (is => 'rw', isa => 'HashRef');


has 'ssh_handler' => ( is => 'ro', isa => 'Net::OpenSSH', handles => qr/.*/);

around BUILDARGS => sub {
    my $orig_call = shift;
    my $s   = shift;

    my $ret = {ip => shift, username => shift,
    password => shift, params => shift};

	my %ssh_param = (
   		user                    => $ret->{username},
   		password                => $ret->{password},
		timeout                 => 5,
		kill_ssh_on_timeout     => 1,
		master_opts             => ["-q", "-o UserKnownHostsFile=/dev/null",
			"-o StrictHostKeyChecking=no"],
	);

    while (my ($k,$v) = each %ssh_param) {
        $ret->{params}->{$k} = $v;
    }
    $ret->{ssh_handler} = new Net::OpenSSH($ret->{ip}, %{$ret->{params}});

    return $s->$orig_call($ret);
};

sub kill_cmd {
    my $s   = shift;
    my $cmd = shift;

    my ($out ,$pid) = $s->pipe_out("ps l|grep '$cmd'");
    my $pid_to_kill = new Set::Array;
    my $parent_excluded = new Set::Array;
    while (<$out>) {
        /\w\s+\d+\s+(?<pid>\d+)\s+(?<ppid>\d+)(?:\s+\d+){2}\s+(?:[\w:]+\s+){3}(?<cmd>.*?)\n/;
        if ($+{cmd} eq $cmd) {
            $pid_to_kill->push($+{pid}) if (!$parent_excluded->exists($+{ppid}));
            $parent_excluded->push($+{pid});
        }
    }
    $pid_to_kill->foreach(sub { $s->system('kill ' . $_)});

    return !$pid_to_kill->is_empty;
}

sub wstalist {
    my $s = shift;
    my ( $out, $err ) = $s->capture2('wstalist');
    return decode_json $out;
}

sub status {
    my $s = shift;
    my $ret = {};
    my ( $out, $err ) = $s->capture2('mca-status');
    my @lines = split(/\r\n/, $out);
    foreach (@lines) {
        if (/=/) {
            my ($k,$v) = split(/=/,$_,2);
            $ret->{$k} = $v;
        }
    }
    my @deviceName =split(/,/, $ret->{deviceName});
    $ret->{deviceName} = shift @deviceName;
    foreach (@deviceName) {
        my ($k,$v) = split(/=/,$_);
        chomp($v);
        $ret->{$k} = $v;

    }
    return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
