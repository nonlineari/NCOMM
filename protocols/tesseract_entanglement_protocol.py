#!/usr/bin/env python3
"""
Enhanced Tesseract Protocol with Entanglement Detection and Return Path

Features:
- Bidirectional tesseract traversal (forward/reverse)
- Entanglement detection via sync error monitoring
- Automatic recovery from stuck states
- Return protocol to ground state
"""

import socket
import json
import numpy as np
import sys
import time
from datetime import datetime


class TesseractEntanglementProtocol:
    """Enhanced disconnect protocol with entanglement detection"""
    
    def __init__(self, host='localhost', port=5555):
        self.host = host
        self.port = port
        self.sock = None
        
        # 4D tesseract structure
        self.n_states = 16
        self.adjacency = self._build_tesseract_adjacency()
        
        # Disconnect state vector [network, transport, session, application]
        self.state = np.zeros(4)
        
        # Entanglement detection
        self.last_ack_time = None
        self.ack_timeouts = 0
        self.entanglement_threshold = 3.0  # seconds
        self.max_timeouts = 3
        
        # History for entanglement detection
        self.sync_error_history = []
        
    def _build_tesseract_adjacency(self):
        """Build 4D tesseract adjacency matrix"""
        adj = np.zeros((self.n_states, self.n_states))
        for i in range(self.n_states):
            for dim in range(4):
                neighbor = i ^ (1 << dim)
                adj[i, neighbor] = 1
        return adj
    
    def _get_dimension_state(self, vertex):
        """Extract dimension states for a vertex"""
        return [(vertex >> dim) & 1 for dim in range(4)]
    
    def _vertex_from_state(self, state):
        """Convert state vector to vertex number"""
        return int(sum(int(bit) << i for i, bit in enumerate(state)))
    
    def connect(self, timeout=2):
        """Establish connection"""
        try:
            print(f"[Tesseract] Connecting to {self.host}:{self.port}...")
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.settimeout(timeout)
            self.sock.connect((self.host, self.port))
            print(f"[Tesseract] ✓ Connected")
            self.last_ack_time = time.time()
            return True
        except Exception as e:
            print(f"[Tesseract] ✗ Connection failed: {e}")
            return False
    
    def send_signal(self, signal_type, dimension=None, state=None):
        """Send signal with optional dimension info"""
        message = {
            'type': signal_type,
            'timestamp': datetime.now().isoformat(),
            'source': 'TesseractProtocol'
        }
        
        if dimension is not None:
            message['dimension'] = dimension
            message['state'] = state
            message['layer'] = ['network', 'transport', 'session', 'application'][dimension]
        
        try:
            message_json = json.dumps(message)
            message_bytes = message_json.encode('utf-8')
            length_prefix = len(message_bytes).to_bytes(4, byteorder='big')
            self.sock.sendall(length_prefix + message_bytes)
            return True
        except Exception as e:
            print(f"[Tesseract] ✗ Send failed: {e}")
            return False
    
    def wait_for_ack(self, timeout=2):
        """Wait for acknowledgment and detect entanglement"""
        try:
            self.sock.settimeout(timeout)
            length_bytes = self.sock.recv(4)
            
            if not length_bytes:
                self.ack_timeouts += 1
                return False
            
            message_length = int.from_bytes(length_bytes, byteorder='big')
            message_bytes = b''
            
            while len(message_bytes) < message_length:
                chunk = self.sock.recv(min(4096, message_length - len(message_bytes)))
                if not chunk:
                    break
                message_bytes += chunk
            
            message = json.loads(message_bytes.decode('utf-8'))
            self.last_ack_time = time.time()
            self.ack_timeouts = 0
            return message.get('type') == 'ACK'
            
        except socket.timeout:
            self.ack_timeouts += 1
            print(f"[Tesseract] ⚠ ACK timeout ({self.ack_timeouts}/{self.max_timeouts})")
            return False
        except Exception as e:
            self.ack_timeouts += 1
            return False
    
    def detect_entanglement(self):
        """
        Detect if connection is in entangled/stuck state
        
        Signs of entanglement:
        1. Multiple ACK timeouts
        2. No response for extended period
        3. Sync error stalling (if available)
        """
        # Check ACK timeouts
        if self.ack_timeouts >= self.max_timeouts:
            print(f"[Tesseract] ⚠ ENTANGLEMENT: {self.ack_timeouts} consecutive timeouts")
            return True
        
        # Check last ACK time
        if self.last_ack_time is not None:
            elapsed = time.time() - self.last_ack_time
            if elapsed > self.entanglement_threshold:
                print(f"[Tesseract] ⚠ ENTANGLEMENT: No response for {elapsed:.1f}s")
                return True
        
        # Check sync error stalling
        if len(self.sync_error_history) > 10:
            recent = self.sync_error_history[-10:]
            variance = np.var(recent)
            if variance < 1e-6:  # Stalled
                print(f"[Tesseract] ⚠ ENTANGLEMENT: Sync error stalled (var={variance:.2e})")
                return True
        
        return False
    
    def traverse_forward_path(self):
        """Generate forward disconnect path: 0000 → 1111"""
        current_vertex = self._vertex_from_state(self.state)
        target_vertex = 15  # 1111
        
        path = []
        while current_vertex != target_vertex:
            diff = current_vertex ^ target_vertex
            dim = (diff & -diff).bit_length() - 1
            next_vertex = current_vertex ^ (1 << dim)
            path.append((current_vertex, next_vertex, dim))
            current_vertex = next_vertex
        
        return path
    
    def traverse_reverse_path(self):
        """Generate reverse return path: 1111 → 0000"""
        current_vertex = self._vertex_from_state(self.state)
        target_vertex = 0  # 0000
        
        path = []
        while current_vertex != target_vertex:
            diff = current_vertex ^ target_vertex
            dim = (diff & -diff).bit_length() - 1
            next_vertex = current_vertex ^ (1 << dim)
            path.append((current_vertex, next_vertex, dim))
            current_vertex = next_vertex
        
        return path
    
    def execute_graceful_disconnect(self):
        """Execute graceful disconnect with entanglement detection"""
        print("\n" + "="*60)
        print("TESSERACT GRACEFUL DISCONNECT")
        print("="*60)
        print(f"Target: {self.host}:{self.port}")
        print("="*60)
        
        path = self.traverse_forward_path()
        
        for step, (from_v, to_v, dim) in enumerate(path):
            from_state = self._get_dimension_state(from_v)
            to_state = self._get_dimension_state(to_v)
            layer_name = ['Network', 'Transport', 'Session', 'Application'][dim]
            
            print(f"\nStep {step+1}/{len(path)}: {layer_name} Layer")
            print(f"  State: {from_state} → {to_state}")
            
            # Send disconnect signal
            if self.sock:
                self.send_signal('TESSERACT_DISCONNECT', dim, to_state[dim])
                
                # Wait for ACK and check entanglement
                if not self.wait_for_ack():
                    if self.detect_entanglement():
                        print("\n[Tesseract] ⚠ ENTANGLEMENT DETECTED!")
                        print("[Tesseract] Switching to force mode...")
                        self.force_disconnect()
                        return False
            
            # Update state
            self.state[dim] = 1
        
        # Close socket
        if self.sock:
            try:
                self.sock.close()
                print("\n[Tesseract] ✓ Socket closed")
            except:
                pass
        
        print("\n" + "="*60)
        print("GRACEFUL DISCONNECT COMPLETE")
        print("="*60)
        return True
    
    def force_disconnect(self):
        """Force disconnect (immediate decoherence)"""
        print("\n" + "="*60)
        print("TESSERACT FORCE DISCONNECT")
        print("="*60)
        print("Forcing decoherence across all dimensions...")
        
        for dim in range(4):
            self.state[dim] = 1
            layer = ['Network', 'Transport', 'Session', 'Application'][dim]
            print(f"  [Dim {dim}] {layer}: FORCED CLOSED")
        
        if self.sock:
            try:
                self.sock.close()
            except:
                pass
        
        print("\n[Tesseract] ✓ All dimensions forced to disconnected")
        print(f"[Tesseract] Final state: {self.state}")
        print("="*60)
        return True
    
    def execute_return_protocol(self):
        """Execute return protocol: 1111 → 0000"""
        print("\n" + "="*60)
        print("TESSERACT RETURN PROTOCOL")
        print("="*60)
        print("Returning to ground state for reconnection...")
        print("="*60)
        
        path = self.traverse_reverse_path()
        
        for step, (from_v, to_v, dim) in enumerate(path):
            from_state = self._get_dimension_state(from_v)
            to_state = self._get_dimension_state(to_v)
            layer_name = ['Network', 'Transport', 'Session', 'Application'][dim]
            
            print(f"\nStep {step+1}/{len(path)}: Reset {layer_name} Layer")
            print(f"  State: {from_state} → {to_state}")
            
            # Reset dimension
            self.state[dim] = 0
            time.sleep(0.1)  # Small delay for visualization
        
        print("\n" + "="*60)
        print("RETURN PROTOCOL COMPLETE")
        print("="*60)
        print(f"Final state: {self.state}")
        print(f"Ground state achieved: {np.all(self.state == 0)}")
        print("System ready for reconnection")
        print("="*60)
        return True
    
    def full_cycle_demo(self):
        """Demonstrate full disconnect-return cycle"""
        print("\n" + "="*60)
        print("TESSERACT FULL CYCLE DEMONSTRATION")
        print("="*60)
        
        # Forward: 0000 → 1111
        print("\n>>> Phase 1: DISCONNECT (Forward Path)")
        self.force_disconnect()
        
        time.sleep(1)
        
        # Reverse: 1111 → 0000
        print("\n>>> Phase 2: RETURN (Reverse Path)")
        self.execute_return_protocol()
        
        print("\n>>> Cycle complete. System ready.")


def main():
    """Main entry point"""
    host = sys.argv[1] if len(sys.argv) > 1 else 'localhost'
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 5555
    
    mode = 'force'
    if '--graceful' in sys.argv:
        mode = 'graceful'
    elif '--return' in sys.argv:
        mode = 'return'
    elif '--cycle' in sys.argv:
        mode = 'cycle'
    
    protocol = TesseractEntanglementProtocol(host=host, port=port)
    
    if mode == 'graceful':
        if protocol.connect():
            protocol.execute_graceful_disconnect()
        else:
            print("\n[Tesseract] Connection failed, using force mode")
            protocol.force_disconnect()
    
    elif mode == 'return':
        # Assume already disconnected, execute return
        protocol.state = np.ones(4)  # Start from 1111
        protocol.execute_return_protocol()
    
    elif mode == 'cycle':
        # Demonstrate full cycle
        protocol.full_cycle_demo()
    
    else:  # force (default)
        protocol.force_disconnect()


if __name__ == '__main__':
    main()
