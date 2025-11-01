package discordcmd;

use strict;
use warnings;
use lib $Plugins::current_plugin_folder."//..//!deps";
use Plugins;
use Commands;
use Log qw(message);
use IO::Socket::INET;
use IO::Select;
use LWP::UserAgent;
use HTTP::Request;
use JSON;
use Globals;

Plugins::register('discordcmd', 'Plugin to send commands from discord', \&on_unload, \&on_reload);

my $hooks = Plugins::addHooks(
   ['start3', \&on_load, undef],
   ['AI_start', \&iterate, undef]
);

my ($log_hook_id, $socket, $bot_token, $channel_id, $discord_url, $bridge_host, $bridge_port);

sub on_load {
	if (!$config{discordcmd}) {
		message "[discordcmd] Unloading plugin because it's disabled in config.txt\n", "system";
		Commands::run('plugin unload discordcmd');
		return;
	}

	$bot_token = $config{discordcmd_botToken};
	if (!$bot_token) {
		message "[discordcmd] Unloading plugin because bot token is not set in config.txt\n", "system";
		Commands::run('plugin unload discordcmd');
		return;
	}

	$channel_id = $config{discordcmd_channelID};
	if (!$channel_id) {
		message "[discordcmd] Unloading plugin because channel ID is not set in config.txt\n", "system";
		Commands::run('plugin unload discordcmd');
		return;
	}

	$bridge_host = $config{discordcmd_bridgeHost} || 'localhost';
	$bridge_port = $config{discordcmd_bridgePort} || 8080;

	$discord_url = "https://discord.com/api/v10/channels/$channel_id/messages";

	$socket = IO::Socket::INET->new(
		PeerHost => $bridge_host,
		PeerPort => $bridge_port,
		Proto    => 'tcp',
		Timeout  => 10
	);

	if (!$socket) {
		message "[discordcmd] Error: Could not connect to $bridge_host:$bridge_port\n", "system";
		message "[discordcmd] Make sure the Discord TCP Bridge is running\n", "system";
		Commands::run('plugin unload discordcmd');
		return;
	}

  $socket->send($channel_id."\n");

	# Add log hook to send messages to Discord
	$log_hook_id = Log::addHook(\&send_to_discord);

	message "[discordcmd] Plugin loaded successfully\n";
}

sub on_unload {
	Plugins::delHooks($hooks);
	if ($socket) {
		close($socket);
	}
	$socket = undef;

	if (defined $log_hook_id) {
		Log::delHook($log_hook_id);
		$log_hook_id = undef;
	}

	message "[discordcmd] Plugin unloaded\n";
}

sub on_reload {
	&on_unload;
}

sub iterate {
	if (!$socket) {
		return;
	}

	my $select = IO::Select->new($socket);
	$select->add($socket);

	# Check if there's data to read
	if (!$select->can_read(0)) {
		return;
	}

	my $message = <$socket>;
	if (!$message) {
    # Socket is closed, unload plugin.
		Commands::run('plugin unload discordcmd');
		return;
	}

	chomp $message;
	Commands::run($message);
}

# Function to send log messages to Discord
sub send_to_discord {
	my ($type, $domain, $level, $globalVerbosity, $message, $user_data, $near, $far) = @_;

	# Skip if caller is not Commands::run
	return unless $far eq 'Commands::run' || $near eq 'Commands::run';

	# Skip NPC responses
	return if $message =~ /Responses/ || $message =~ /Store List/;

	# Filter messages - only send certain types/domains to avoid spam
	my @allowed_types = qw(message error);
	my @allowed_domains = qw(list info);

	# Skip if domain or type is not in allowed lists
	return unless grep { $_ eq $type } @allowed_types;
	return if $type eq 'message' && !grep { $_ eq $domain } @allowed_domains;

	# Clean up the message - only trim leading/trailing whitespace, preserve newlines
	$message =~ s/^\s+|\s+$//g;

	return unless $message;

	my $discord_message = {
		content => "**$char->{name}**\n```\n$message\n```"
	};

	# Send to Discord.
	my $json_payload = encode_json($discord_message);
	eval {
		my $ua = LWP::UserAgent->new();
		$ua->timeout(3);
		$ua->agent('Application');

		my $request = HTTP::Request->new(POST => $discord_url);
		$request->header('Content-Type' => 'application/json');
		$request->header('Authorization' => "Bot $bot_token");
		$request->content($json_payload);

		$ua->request($request);
	} or do {
		# do nothing
	};
}

1;



