import sys
import os
import socket
import select
import threading
import yaml
from PyQt5.QtWidgets import QApplication, QWidget, QVBoxLayout, QTextEdit, QLabel
from PyQt5.QtCore import pyqtSignal, QObject

# Dictionary to hold GUI windows for each port
windows = {}

# Thread-safe signal handler
class SignalHandler(QObject):
    new_message = pyqtSignal(int, str)  # Signal: (port, message)

# Create a global signal handler instance
signal_handler = SignalHandler()

# Load headers from headers.yaml
with open("headers.yaml", "r") as file:
    headers_config = yaml.safe_load(file)

def get_headers(packet_type):
    """Retrieve headers for the given packet type."""
    return ["source"] + headers_config["packets"].get(packet_type, {}).get("variables", [])

def get_port_variable_mapping(headers_file="headers.yaml"):
    """Returns a dictionary mapping port numbers to variable lists from headers.yaml."""
    with open(headers_file, "r") as file:
        headers_config = yaml.safe_load(file)

    port_variable_map = {}
    
    for packet_type, packet_info in headers_config.get("packets", {}).items():
        port = packet_info.get("port")
        variables = packet_info.get("variables", [])
        if port:  # Ensure there's a port defined
            port_variable_map[port] = variables

    return port_variable_map

class PortWindow(QWidget):
    """ GUI window for each port, staggered so they don't overlap """
    window_offset = 0  # Class-level variable to track window position

    def __init__(self, port):
        super().__init__()
        self.port = port
        self.init_ui()

    def init_ui(self):
        self.setWindowTitle(f"Port {self.port}")

        # Set the window position dynamically to stagger windows
        x_offset = 100 + PortWindow.window_offset * 50
        y_offset = 100 + PortWindow.window_offset * 50
        self.setGeometry(x_offset, y_offset, 500, 400)
        PortWindow.window_offset += 1  # Increment for the next window

        layout = QVBoxLayout()

        # Label for the port number
        self.label = QLabel(f"Listening on Port {self.port}", self)
        layout.addWidget(self.label)

        # Text area to display messages
        self.text_edit = QTextEdit(self)
        self.text_edit.setReadOnly(True)
        layout.addWidget(self.text_edit)

        self.setLayout(layout)

    def update_messages(self, message):
        """Updates the text area with the latest message"""
        self.text_edit.append(message)  # Append new message

# Function to handle UDP listening
def udp_listener():
    sockets = []

    ports = get_port_variable_mapping().keys()
    for port in ports:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind(("0.0.0.0", port))  # Listen on all available network interfaces
        sockets.append(sock)

    print(f"Listening for UDP data on ports {ports}...")

    try:
        while True:
            readable, _, _ = select.select(sockets, [], [])

            for sock in readable:
                data, addr = sock.recvfrom(1024)  # Receive up to 1024 bytes
                port = sock.getsockname()[1]
                filename = f"data-{port}.csv"

                message = data.decode('utf-8', errors='ignore').strip()
                #print(f"Received from {addr} on port {port}: {message}")

                # Check if the file exists to determine if the header should be written
                file_exists = os.path.exists(filename)

                with open(filename, "a", newline="") as csvfile:
                    if not file_exists:
                        # Convert list to a comma-separated string
                        vars_list = get_port_variable_mapping()[port]
                        header = "source," + ",".join(vars_list)  
                        csvfile.write(header + "\n")  # Write without csv.writer

                    csvfile.write(message + "\n")  # Write message directly

                # Emit signal to update GUI
                signal_handler.new_message.emit(port, message)

    except KeyboardInterrupt:
        print("\nStopping UDP listener.")
    finally:
        # Close sockets
        for sock in sockets:
            sock.close()

def main():
    # Start PyQt5 application in the main thread
    app = QApplication(sys.argv)

    # Create windows for each port
    for port in get_port_variable_mapping().keys():
        windows[port] = PortWindow(port)
        windows[port].show()

    # Connect signal to window updates
    signal_handler.new_message.connect(lambda port, msg: windows[port].update_messages(msg))

    # Start UDP listener in a separate thread
    udp_thread = threading.Thread(target=udp_listener, daemon=True)
    udp_thread.start()

    # Start GUI event loop
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()