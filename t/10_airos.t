use Test::More;
use Net::OpenSSH::Vendor::AirOs;
use Set::Array;

unless ($ENV{SSH_IP} && $ENV{SSH_USERNAME} && $ENV{SSH_PASSWORD}) {
    my $response = 'You must set SSH_IP, SSH_USERNAME, SSH_PASSWORD env ' .
        'to enable this test';
    plan skip_all => $response;
}

my $num = 0;

my $ssh = new Net::OpenSSH::Vendor::AirOs(
    $ENV{SSH_IP}, $ENV{SSH_USERNAME}, $ENV{SSH_PASSWORD}, {});

plan skip_all => 'Unable to establish SSH connection to ' . $ENV{SSH_IP}
        if $ssh->error;

# check echo shell command
my $cmd = 'echo';
$num++;
is($ssh->capture($cmd), "\n", "check echo command");

# check if is AirOs
$cmd = 'which mca-status';
$num++;
like($ssh->capture($cmd), qr/\/mca-status/, "check mca-status so AirOs");

# read output while running
my $check_str = 'Looping ... number';
my $cmd = "for i in 1 2 3 4 5\ndo\necho \"$check_str \$i\"\ndone";
my ($out, $pid) = $ssh->pipe_out($cmd);
while (<$out>) {
    $num++;
    is($_, $check_str . ' '. ($num-2) . "\n", "check $check_str " . ($num-2) );
 }
close $out;

# kill a daemon
$cmd = 'iperf -s';
$num++;
$ssh->system({stdout_discard => 1}, $cmd);
#sleep 2;
ok($ssh->kill_cmd($cmd), 'Kill a daemon');

# registered clients
use Data::Dumper;
#print Data::Dumper::Dumper($ssh->wstalist);
print Data::Dumper::Dumper($ssh->status);

done_testing($num);
