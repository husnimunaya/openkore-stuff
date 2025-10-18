package statsd;

use strict;
use warnings;
use Plugins;
use Globals qw($char %config %monsters $monstarttime);
use Log qw(message error warning);
use Time::HiRes qw(time);
use Net::Dogstatsd;
use Skill;

# Plugin registration
Plugins::register('statsd', 'OpenKore StatsD metrics plugin', \&onUnload, \&onUnload);

# Configuration
my $statsd_host = $config{statsd_host} || 'localhost';
my $statsd_port = $config{statsd_port} || '8125';
my $statsd_prefix = $config{statsd_prefix} || 'openkore_';

# StatsD client
my $statsd_client;

# Attack tracking
my %attack_starts = ();
my %total_dmg = ();

# Hook registration
my $hooks = Plugins::addHooks(
	['attack_start', \&onAttackStart, undef],
	['target_died', \&onTargetDied, undef],
	['attack_end', \&onAttackEnd, undef],
	['packet_attack', \&onPacketAttack, undef],
	['packet_skilluse', \&onPacketSkilluse, undef]
);

# Lazy initialization of StatsD client
sub get_statsd_client {
	return $statsd_client if $statsd_client;

	eval {
		$statsd_client = Net::Dogstatsd->new(
			host    => $statsd_host,
			port    => $statsd_port,
		);
		message "[statsd] StatsD client initialized (${statsd_host}:${statsd_port})\n", "system";
	};
	if ($@) {
		error "[statsd] Failed to initialize StatsD client: $@\n";
		return undef;
	}

	return $statsd_client;
}

sub onAttackStart {
	return unless $config{statsd};

	my (undef, $args) = @_;
	my $targetID = $args->{ID};

	if ($targetID) {
		$attack_starts{$targetID} = time();
	}
}

sub onTargetDied {
	return unless $config{statsd};

	my (undef, $args) = @_;
	my $monster = $args->{monster};

	return unless $monster && get_statsd_client();

	my $targetID = $monster->{ID};
	my $start_time = $attack_starts{$targetID};

	if (defined $start_time) {
		my $monkilltime = time();
		# start_time is when actor starts initiating the attack, including the time to route to monster.
		# monstarttime is when actor actually starts attacking the monster.
		my $duration = $monkilltime - $monstarttime;

		return if (($monstarttime == 0) || ($monkilltime < $monstarttime));


		my $char_name = sanitize_tag($char->{name} || 'unknown');
		my $monster_name = sanitize_tag($monster->{name} || 'unknown');
		my @tags = (
			"character:${char_name}",
			"monster:${monster_name}"
		);

		my $dps = 0;
		if (exists $total_dmg{$targetID} && $total_dmg{$targetID} > 0) {
			$dps = $total_dmg{$targetID} / $duration;
		}

		eval {
			get_statsd_client()->histogram(
				name => $statsd_prefix . "monster_kill_duration_seconds",
				value => $duration,
				tags => \@tags,
			);

			message sprintf("[statsd] Monster kill metric sent: %s killed %s in %.2fs\n", $char_name, $monster_name, $duration), "system" if $config{statsd_debug};

			if ($dps > 0) {
				get_statsd_client()->histogram(
					name => $statsd_prefix . "damage_per_second",
					value => $dps,
					tags => \@tags,
				);

				message sprintf("[statsd] DPS metric sent: %s dealt %.2f dmg/s to %s\n", $char_name, $dps, $monster_name), "system" if $config{statsd_debug};
			}
		};
		if ($@) {
			error "[statsd] Failed to send metrics: $@\n";
		}

		# Cleanup
		delete $attack_starts{$targetID};
		delete $total_dmg{$targetID};
	}
}

sub onPacketAttack {
	return unless $config{statsd};

	my (undef, $args) = @_;
	return unless get_statsd_client();
	return unless $args->{sourceID} eq $char->{ID};

	my $target = $monsters{$args->{targetID}};
	return unless $target;

	my $char_name = sanitize_tag($char->{name} || 'unknown');
	my $monster_name = sanitize_tag($target->{name} || 'unknown');

	my $metric_name = $statsd_prefix . "attack_dmg";
	my @tags = (
		"character:${char_name}",
		"monster:${monster_name}"
	);

	$total_dmg{$args->{targetID}} += $args->{dmg};

	eval {
		get_statsd_client()->histogram(
			name => $metric_name,
			value => $args->{dmg},
			tags => \@tags,
		);
	};
	if ($@) {
		error "[statsd] Failed to send attack damage metric: $@\n";
	}
}

sub onPacketSkilluse {
	return unless $config{statsd};

	my (undef, $args) = @_;
	return unless get_statsd_client();
	return unless $args->{damage} > 0;
	return unless $args->{sourceID} eq $char->{ID};

	my $target = $monsters{$args->{targetID}};
	return unless $target;

	my $char_name = sanitize_tag($char->{name} || 'unknown');
	my $monster_name = sanitize_tag($target->{name} || 'unknown');

	my $skill = new Skill(idn => $args->{skillID});
	my $skill_name = sanitize_tag($skill->getName() || 'unknown');

	my $metric_name = $statsd_prefix . "skilluse_dmg";
	my @tags = (
		"character:${char_name}",
		"monster:${monster_name}",
		"skill:${skill_name}"
	);

	$total_dmg{$args->{targetID}} += $args->{damage};

	eval {
		get_statsd_client()->histogram(
			name => $metric_name,
			value => $args->{damage},
			tags => \@tags,
		);
	};
	if ($@) {
		error "[statsd] Failed to send skill damage metric: $@\n";
	}
}

sub onAttackEnd {
	return unless $config{statsd};

	my (undef, $args) = @_;
	my $targetID = $args->{ID};

	# Clean up if attack ended without death
	if (exists $attack_starts{$targetID}) {
		delete $attack_starts{$targetID};
	}
}

sub onUnload {
	Plugins::delHooks($hooks);
	%attack_starts = ();
	%total_dmg = ();
	undef $statsd_client;
	message "[statsd] Plugin unloaded\n", "system" if $config{statsd_debug};
}

# Metric tag can only contain letters, numbers, underscores, and hyphens
sub sanitize_tag {
	my ($name) = @_;
	$name =~ s/[^a-zA-Z0-9_-]/_/g;
	return lc($name);
}

1;
