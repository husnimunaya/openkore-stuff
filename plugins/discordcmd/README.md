# discordcmd - Run OpenKore Command on Discord

This plugin allows you to run OpenKore commands from Discord. This plugin requires the [Discord TCP Bridge](https://github.com/husnimunaya/openkore-stuff/tree/main/extras/discord-tcp-bridge) to be running.

## Dependencies

This plugins requires several Perl modules. Install them using [cpanm](https://metacpan.org/dist/App-cpanminus/view/bin/cpanm):

```bash
cpanm LWP::UserAgent
cpanm JSON
```

## Configuration

Add the following settings to your `config.txt`:

```
discordcmd 1
discordcmd_botToken <your_bot_token>
discordcmd_channelID <your_channel_id>
discordcmd_bridgeHost localhost  # Host of the Discord TCP Bridge. Optional, default is localhost. 
discordcmd_bridgePort 8080       # Port of the Discord TCP Bridge. Optional, default is 8080.
```

## Usage

Once the plugin is loaded, you can send commands to OpenKore from Discord. Read the [Discord TCP Bridge](https://github.com/husnimunaya/openkore-stuff/tree/main/extras/discord-tcp-bridge) README for more information on how to setup the Discord Bot.

## Known Issues

- Not all OpenKore commands output will be forwarded to Discord such as `storage` and `eq`.
- This will not work with the precompiled Windows binaries due to SSL issues on older version of Perl. If you are on Windows, you can use [Strawberry Perl](https://strawberryperl.com/) to run OpenKore (`perl openkore.pl`).