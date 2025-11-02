# Discord TCP Bridge

A Go program that connects to Discord's gateway WebSocket and streams messages from a specific channel to stdout and forwards them to TCP clients.

## Dependencies

This program requires Go 1.24 or higher. To install Go, follow the instructions [here](https://go.dev/doc/install).

## Setup

### 1. Create a Discord Bot

1. Go to https://discord.com/developers/applications
2. Click "New Application" and give it a name
3. Go to the "Bot" section in the left sidebar
4. Click "Add Bot"
5. Under the "Token" section, click "Copy" to get your bot token
6. **Important**: Enable "Message Content Intent" under "Privileged Gateway Intents"

### 2. Invite Bot to Your Server

1. Go to "OAuth2" → "URL Generator" section
2. Select "bot" scope
3. Select "Read Messages" and "Read Message History" permissions
4. Copy the generated URL and open it to invite the bot to your server

### 3. Get Channel ID

1. Enable Developer Mode in Discord (User Settings → Advanced → Developer Mode)
2. Right-click on the channel you want to monitor and select "Copy ID"

## Usage

### Set Environment Variables

```bash
# Linux
export DISCORD_BOT_TOKEN="your_bot_token_here"
export TCP_PORT="8080"  # Optional, defaults to 8080

# Windows Command Line
set DISCORD_BOT_TOKEN="your_bot_token_here"
set TCP_PORT="8080"  # Optional, defaults to 8080
```

Or create a `.env` file in the project directory:
```
DISCORD_BOT_TOKEN=your_bot_token_here
TCP_PORT=8080
```

### Run the Program

```bash
go run main.go
```

The program will:
- Connect to Discord's gateway WebSocket
- Start a TCP server on the specified port (default: 8080)
- Listen for messages
- Forward all messages to connected TCP clients


## Connecting TCP Clients

You can connect to the TCP server using any TCP client. Examples:

### Using telnet
```bash
telnet localhost 8080
<DISCCORD_CHANNEL_ID>
```

### Using netcat
```bash
nc localhost 8080
<DISCCORD_CHANNEL_ID>
```
