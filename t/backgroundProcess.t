package Runner;
use Moose;

with 'Bio::EnsEMBL::Mongoose::Utils::BackgroundLauncher';

1;

use strict;
use Test::More;
use Test::Differences;

my $runner = Runner->new(command => './bin/fake_server.pl', args => { '--param' => 2 });
$runner->run_command();
ok($runner->get_pid(),'Make sure a PID got assigned to a process');
note $runner->get_pid();
ok($runner->background_process_alive,'Process alive at the moment');
sleep 1;
ok($runner->background_process_alive,'Process still alive');
sleep 2;
ok(!$runner->background_process_alive,'Process finished');

# Launch a 20-second process before asking it to close early
$runner = Runner->new(command => './bin/fake_server.pl', args => { param => 20 });
$runner->run_command();
note $runner->get_pid();
my $pid = $runner->get_pid();
ok($runner->background_process_alive,'Started longer running process');
$runner->stop_background_process();
my $exists = kill 0,$pid;
ok (!$exists, 'Process shutdown nicely when asked');
ok(!$runner->background_process_alive,'Code does not believe process is still running');

done_testing();