package main

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"

	"github.com/bwmarrin/discordgo"
	"github.com/subosito/gotenv"
)

// TCPServer manages TCP connections and message broadcasting
type TCPServer struct {
	listener    net.Listener
	clients     map[net.Conn]string
	clientsMux  sync.RWMutex
	messageChan chan Message
}

type Message struct {
	Content   string
	ChannelID string
}

// NewTCPServer creates a new TCP server
func NewTCPServer(port int) (*TCPServer, error) {
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		return nil, err
	}

	server := &TCPServer{
		listener:    listener,
		clients:     make(map[net.Conn]string),
		messageChan: make(chan Message, 100),
	}

	return server, nil
}

// Start starts the TCP server and begins accepting connections
func (s *TCPServer) Start() {
	go s.acceptConnections()
	go s.broadcastMessages()
	log.Printf("TCP server started on %s", s.listener.Addr().String())
}

// Stop stops the TCP server
func (s *TCPServer) Stop() {
	s.listener.Close()
	s.clientsMux.Lock()
	for client := range s.clients {
		client.Close()
	}
	s.clientsMux.Unlock()
	close(s.messageChan)
}

// acceptConnections handles incoming TCP connections
func (s *TCPServer) acceptConnections() {
	for {
		conn, err := s.listener.Accept()
		if err != nil {
			log.Printf("Error accepting connection: %v", err)
			return
		}

		s.clientsMux.Lock()
		s.clients[conn] = ""
		s.clientsMux.Unlock()

		log.Printf("New TCP client connected: %s", conn.RemoteAddr().String())

		go func(c net.Conn) {
			for {
				// The client must send the channel ID when connected.
				reader := bufio.NewReader(c)
				channelID, err := reader.ReadString('\n')
				if err != nil {
					// Client disconnected.
					s.clientsMux.Lock()
					delete(s.clients, c)
					s.clientsMux.Unlock()
					c.Close()
					log.Printf("TCP client disconnected: %s", c.RemoteAddr().String())
					return
				}

				channelID = strings.TrimSpace(channelID)
				s.clientsMux.Lock()
				s.clients[c] = channelID
				s.clientsMux.Unlock()
				log.Printf("Client %s connected to channel %s", c.RemoteAddr().String(), channelID)
			}
		}(conn)
	}
}

// broadcastMessages sends messages to all connected TCP clients
func (s *TCPServer) broadcastMessages() {
	for message := range s.messageChan {
		s.clientsMux.RLock()
		for client, channelID := range s.clients {
			if message.ChannelID != channelID {
				continue
			}

			_, err := client.Write([]byte(message.Content + "\n"))
			if err != nil {
				log.Printf("Error writing to client %s: %v", client.RemoteAddr().String(), err)
			}
		}
		s.clientsMux.RUnlock()
	}
}

// SendMessage queues a message to be sent to all TCP clients
func (s *TCPServer) SendMessage(message Message) {
	select {
	case s.messageChan <- message:
	default:
		log.Println("Message channel full, dropping message")
	}
}

func main() {
	gotenv.Load("./.env")

	token := os.Getenv("DISCORD_BOT_TOKEN")
	if token == "" {
		log.Fatal("DISCORD_BOT_TOKEN environment variable is required")
	}

	tcpPortStr := os.Getenv("TCP_PORT")
	if tcpPortStr == "" {
		tcpPortStr = "8080"
	}

	tcpPort, err := strconv.Atoi(tcpPortStr)
	if err != nil {
		log.Fatal("Invalid TCP_PORT value: ", err)
	}

	tcpServer, err := NewTCPServer(tcpPort)
	if err != nil {
		log.Fatal("Error creating TCP server: ", err)
	}

	tcpServer.Start()
	defer tcpServer.Stop()

	dg, err := discordgo.New("Bot " + token)
	if err != nil {
		log.Fatal("Error creating Discord session: ", err)
	}

	dg.AddHandler(func(s *discordgo.Session, m *discordgo.MessageCreate) {
		messageCreate(s, m, tcpServer)
	})

	dg.Identify.Intents = discordgo.IntentsGuildMessages | discordgo.IntentsMessageContent

	err = dg.Open()
	if err != nil {
		log.Fatal("Error opening connection: ", err)
	}

	fmt.Printf("TCP server listening on port %d\n", tcpPort)
	fmt.Println("Press CTRL-C to exit.")

	sc := make(chan os.Signal, 1)
	signal.Notify(sc, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	<-sc

	dg.Close()
}

// messageCreate will be called every time a new message is created on any channel
func messageCreate(s *discordgo.Session, m *discordgo.MessageCreate, tcpServer *TCPServer) {
	log.Printf("Message created: %s %s", m.Content, m.ChannelID)

	// Ignore messages from the bot itself
	if m.Author.ID == s.State.User.ID {
		return
	}

	// Only process messages from registered channel IDs.
	channelFound := false
	for _, channelID := range tcpServer.clients {
		if m.ChannelID == channelID {
			channelFound = true
			break
		}
	}

	log.Printf("Channel found: %v", channelFound)

	if !channelFound {
		return
	}

	tcpServer.SendMessage(Message{Content: m.Content, ChannelID: m.ChannelID})
}
