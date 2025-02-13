import socket
import yaml
import sys
from PyQt5.QtWidgets import QApplication, QWidget, QVBoxLayout, QTextEdit
from PyQt5.QtCore import QThread, pyqtSignal

class PacketListener(QThread):
    packet_received = pyqtSignal(str)
    
    def __init__(self, config_file):
        super().__init__()
        self.config_file = config_file
        self.packets = self.load_config()
        self.sockets = {}
        self.running = False
    
    def load_config(self):
        """Loads the packet configuration from the YAML file."""
        with open(self.config_file, 'r') as file:
            return yaml.safe_load(file)['packets']
    
    def setup_sockets(self):
        """Initializes sockets based on the configuration."""
        for packet_name, packet_info in self.packets.items():
            if packet_info['listen']:
                port = packet_info['port']
                self.sockets[packet_name] = self.create_socket(port)
                print(f"Listening on port {port} for {packet_name}...")
    
    def create_socket(self, port):
        """Creates and binds a socket to the given port."""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(("", port))
        sock.settimeout(1.0)  # Set timeout to allow graceful shutdown
        return sock
    
    def run(self):
        """Listens for incoming packets on configured ports."""
        self.setup_sockets()
        self.running = True
        print("Listening for packets...")
        while self.running:
            for packet_name, sock in self.sockets.items():
                try:
                    data, addr = sock.recvfrom(1024)
                    message = f"Received packet: {packet_name} from {addr}\nData: {data.decode()}\n"
                    self.packet_received.emit(message)
                except socket.timeout:
                    continue  # Allows checking self.running to exit loop cleanly
    
    def stop(self):
        """Stops listening for packets."""
        self.running = False
        self.wait()
        print("Stopped listening.")

class PacketListenerGUI(QWidget):
    def __init__(self):
        super().__init__()
        self.initUI()
        self.listener = PacketListener("headers.yaml")
        self.listener.packet_received.connect(self.display_packet)
        self.listener.start()
    
    def initUI(self):
        """Initializes the GUI components."""
        self.setWindowTitle("Packet Listener")
        self.setGeometry(100, 100, 600, 400)
        
        layout = QVBoxLayout()
        self.text_display = QTextEdit()
        self.text_display.setReadOnly(True)
        layout.addWidget(self.text_display)
        
        self.setLayout(layout)
    
    def display_packet(self, message):
        """Displays received packets in the text area."""
        self.text_display.append(message)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    gui = PacketListenerGUI()
    gui.show()
    sys.exit(app.exec_())
