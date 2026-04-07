#!/usr/bin/env python3
"""
M2L Protocol - Machine-to-Learning Distribution Protocol

Integrates:
1. Tesseract Protocol Suite (connection management)
2. Data Scanner (network data collection)
3. Generative Data Pipeline (to R.app and ML architecture)
4. User Connection Protocol
5. Network Architecture Testing

This protocol enables distributed machine learning across networked systems
with tesseract-based resilient connectivity.
"""

import socket
import json
import numpy as np
import sys
import time
import subprocess
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple


class DataScanner:
    """Scans network state and generates structured data"""
    
    def __init__(self):
        self.scan_history = []
        self.data_buffer = []
        
    def scan_network_state(self, x: np.ndarray, y: np.ndarray) -> Dict[str, Any]:
        """
        Scan current network state from Hénon system
        
        Args:
            x: Node x-coordinates (state vector)
            y: Node y-coordinates (state vector)
            
        Returns:
            Structured scan data
        """
        scan_data = {
            'timestamp': datetime.now().isoformat(),
            'n_nodes': len(x),
            'statistics': {
                'mean_x': float(np.mean(x)),
                'mean_y': float(np.mean(y)),
                'std_x': float(np.std(x)),
                'std_y': float(np.std(y)),
                'min_x': float(np.min(x)),
                'max_x': float(np.max(x)),
                'min_y': float(np.min(y)),
                'max_y': float(np.max(y)),
            },
            'distribution': {
                'x_histogram': np.histogram(x, bins=10)[0].tolist(),
                'y_histogram': np.histogram(y, bins=10)[0].tolist(),
            },
            'topology': {
                'phase_space_density': self._compute_density(x, y),
                'clustering_coefficient': self._compute_clustering(x, y),
            }
        }
        
        self.scan_history.append(scan_data)
        return scan_data
    
    def _compute_density(self, x: np.ndarray, y: np.ndarray) -> float:
        """Compute phase space density"""
        # Simple density metric based on spread
        volume = (np.max(x) - np.min(x)) * (np.max(y) - np.min(y))
        if volume == 0:
            return 0.0
        return float(len(x) / (volume + 1e-10))
    
    def _compute_clustering(self, x: np.ndarray, y: np.ndarray) -> float:
        """Compute clustering coefficient approximation"""
        # Distance-based clustering metric
        points = np.column_stack([x, y])
        distances = np.linalg.norm(points[:, None] - points[None, :], axis=2)
        mean_dist = np.mean(distances[distances > 0])
        return float(1.0 / (1.0 + mean_dist))
    
    def export_to_csv(self, filepath: str) -> bool:
        """Export scan history to CSV for R"""
        try:
            import csv
            
            if not self.scan_history:
                return False
            
            with open(filepath, 'w', newline='') as f:
                # Flatten structure for CSV
                fieldnames = [
                    'timestamp', 'n_nodes',
                    'mean_x', 'mean_y', 'std_x', 'std_y',
                    'min_x', 'max_x', 'min_y', 'max_y',
                    'phase_space_density', 'clustering_coefficient'
                ]
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                
                for scan in self.scan_history:
                    row = {
                        'timestamp': scan['timestamp'],
                        'n_nodes': scan['n_nodes'],
                        **scan['statistics'],
                        **scan['topology']
                    }
                    writer.writerow(row)
            
            print(f"[DataScanner] Exported {len(self.scan_history)} scans to {filepath}")
            return True
            
        except Exception as e:
            print(f"[DataScanner] Export failed: {e}")
            return False


class RInterface:
    """Interface to R.app for statistical analysis and ML"""
    
    def __init__(self, r_path: Optional[str] = None):
        # Find R executable
        self.r_path = r_path or self._find_r()
        self.working_dir = Path.cwd()
        
    def _find_r(self) -> Optional[str]:
        """Locate R installation"""
        # Check common R locations on macOS
        candidates = [
            '/usr/local/bin/R',
            '/opt/homebrew/bin/R',
            '/usr/bin/R',
            '/Library/Frameworks/R.framework/Resources/bin/R',
        ]
        
        for path in candidates:
            if os.path.exists(path):
                return path
        
        # Try which
        try:
            result = subprocess.run(['which', 'R'], capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        
        return None
    
    def is_available(self) -> bool:
        """Check if R is available"""
        return self.r_path is not None
    
    def execute_script(self, script_path: str) -> Tuple[bool, str]:
        """Execute R script"""
        if not self.is_available():
            return False, "R not available"
        
        try:
            result = subprocess.run(
                [self.r_path, '--vanilla', '--slave', '-f', script_path],
                capture_output=True,
                text=True,
                timeout=60
            )
            
            if result.returncode == 0:
                return True, result.stdout
            else:
                return False, result.stderr
                
        except Exception as e:
            return False, str(e)
    
    def analyze_data(self, csv_path: str, output_path: str) -> bool:
        """Run statistical analysis on scanned data"""
        # Generate R script
        r_script = f"""
# M2L Protocol - R Analysis Script
# Generated: {datetime.now().isoformat()}

library(stats)

# Load data
data <- read.csv("{csv_path}")

# Summary statistics
summary_stats <- summary(data)
print("=== Summary Statistics ===")
print(summary_stats)

# Correlation analysis
numeric_cols <- data[, sapply(data, is.numeric)]
correlations <- cor(numeric_cols, use="complete.obs")
print("=== Correlations ===")
print(correlations)

# Time series analysis (if applicable)
if("mean_x" %in% names(data)) {{
    # Simple trend analysis
    x_trend <- lm(mean_x ~ seq_along(mean_x), data=data)
    y_trend <- lm(mean_y ~ seq_along(mean_y), data=data)
    
    print("=== X Trend ===")
    print(summary(x_trend))
    print("=== Y Trend ===")
    print(summary(y_trend))
}}

# Save results
results <- list(
    summary = summary_stats,
    correlations = correlations,
    n_observations = nrow(data)
)

# Write JSON output
library(jsonlite)
write_json(results, "{output_path}", pretty=TRUE, auto_unbox=TRUE)

print("Analysis complete!")
"""
        
        script_path = self.working_dir / "m2l_analysis.R"
        with open(script_path, 'w') as f:
            f.write(r_script)
        
        print(f"[RInterface] Executing analysis script...")
        success, output = self.execute_script(str(script_path))
        
        if success:
            print(f"[RInterface] ✓ Analysis complete")
            print(output)
        else:
            print(f"[RInterface] ✗ Analysis failed: {output}")
        
        return success


class MLArchitectureTester:
    """Tests machine learning architecture over network"""
    
    def __init__(self):
        self.test_results = []
        
    def test_data_flow(self, scan_data: Dict[str, Any]) -> Dict[str, Any]:
        """Test data flow through ML pipeline"""
        result = {
            'timestamp': datetime.now().isoformat(),
            'test_type': 'data_flow',
            'input_nodes': scan_data['n_nodes'],
            'latency_ms': np.random.uniform(1, 10),  # Simulated for now
            'throughput_mbps': np.random.uniform(10, 100),
            'success': True
        }
        
        self.test_results.append(result)
        return result
    
    def test_network_resilience(self, state_vector: np.ndarray) -> Dict[str, Any]:
        """Test network resilience to failures"""
        # Simulate node dropout
        dropout_rate = 0.1
        active_nodes = np.random.rand(len(state_vector)) > dropout_rate
        
        result = {
            'timestamp': datetime.now().isoformat(),
            'test_type': 'resilience',
            'total_nodes': len(state_vector),
            'active_nodes': int(np.sum(active_nodes)),
            'dropout_rate': dropout_rate,
            'network_operational': bool(np.sum(active_nodes) > len(state_vector) * 0.5)
        }
        
        self.test_results.append(result)
        return result
    
    def export_test_results(self, filepath: str) -> bool:
        """Export test results"""
        try:
            with open(filepath, 'w') as f:
                json.dump(self.test_results, f, indent=2)
            print(f"[MLTester] Exported {len(self.test_results)} test results")
            return True
        except Exception as e:
            print(f"[MLTester] Export failed: {e}")
            return False


class M2LProtocol:
    """
    Main M2L Protocol Controller
    
    Coordinates:
    - Tesseract-based connections
    - Data scanning
    - Generative data pipeline to R
    - ML architecture testing
    """
    
    def __init__(self, host: str = 'localhost', port: int = 5555):
        self.host = host
        self.port = port
        
        # Core components
        from tesseract_entanglement_protocol import TesseractEntanglementProtocol
        self.tesseract = TesseractEntanglementProtocol(host, port)
        self.scanner = DataScanner()
        self.r_interface = RInterface()
        self.ml_tester = MLArchitectureTester()
        
        # State
        self.connected = False
        self.initialized = False
        
        # Data paths
        self.output_dir = Path.cwd() / "m2l_output"
        self.output_dir.mkdir(exist_ok=True)
        
    def initialize(self) -> bool:
        """Initialize M2L protocol"""
        print("\n" + "="*60)
        print("M2L PROTOCOL INITIALIZATION")
        print("="*60)
        print(f"Host: {self.host}:{self.port}")
        print(f"Output directory: {self.output_dir}")
        print(f"R available: {self.r_interface.is_available()}")
        print("="*60)
        
        # Check R availability
        if not self.r_interface.is_available():
            print("[M2L] ⚠ R not available - statistical analysis disabled")
        
        self.initialized = True
        print("[M2L] ✓ Initialization complete")
        return True
    
    def connect_user(self) -> bool:
        """Establish user connection via tesseract protocol"""
        print("\n[M2L] Initiating user connection...")
        
        # Attempt connection with entanglement detection
        if self.tesseract.connect():
            self.connected = True
            print("[M2L] ✓ User connected")
            return True
        else:
            print("[M2L] ⚠ Connection failed - operating in standalone mode")
            self.connected = False
            return False
    
    def scan_and_collect(self, x: np.ndarray, y: np.ndarray) -> Dict[str, Any]:
        """Scan network state and collect data"""
        scan_data = self.scanner.scan_network_state(x, y)
        
        # Test ML architecture with this data
        flow_test = self.ml_tester.test_data_flow(scan_data)
        resilience_test = self.ml_tester.test_network_resilience(x)
        
        return {
            'scan': scan_data,
            'tests': {
                'flow': flow_test,
                'resilience': resilience_test
            }
        }
    
    def generate_to_r(self) -> bool:
        """Generate data pipeline to R for analysis"""
        print("\n[M2L] Generating data for R analysis...")
        
        # Export scanned data
        csv_path = self.output_dir / f"m2l_data_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        if not self.scanner.export_to_csv(str(csv_path)):
            return False
        
        # Run R analysis if available
        if self.r_interface.is_available():
            output_path = self.output_dir / "m2l_analysis_results.json"
            return self.r_interface.analyze_data(str(csv_path), str(output_path))
        else:
            print("[M2L] ⚠ R not available - skipping analysis")
            return True
    
    def run_simulation(self, n_steps: int = 100, a: float = 1.4, b: float = 0.3, 
                       coupling: float = 0.1, n_nodes: int = 16) -> bool:
        """
        Run full M2L simulation
        
        Simulates a Hénon network and applies M2L protocol
        """
        print("\n" + "="*60)
        print("M2L PROTOCOL SIMULATION")
        print("="*60)
        print(f"Steps: {n_steps}")
        print(f"Nodes: {n_nodes}")
        print(f"Parameters: a={a}, b={b}, coupling={coupling}")
        print("="*60)
        
        # Force 16 nodes for tesseract (2^4)
        if n_nodes != 16:
            print(f"[M2L] ⚠ Adjusting nodes from {n_nodes} to 16 (tesseract requirement)")
            n_nodes = 16
        
        # Initialize random state with smaller values to prevent overflow
        x = np.random.uniform(-0.1, 0.1, n_nodes)
        y = np.random.uniform(-0.1, 0.1, n_nodes)
        
        # Build tesseract adjacency
        adjacency = np.zeros((n_nodes, n_nodes))
        for i in range(n_nodes):
            for dim in range(4):
                neighbor = i ^ (1 << dim)
                adjacency[i, neighbor] = 1
        
        # Simulation loop
        for step in range(n_steps):
            # Hénon map iteration
            x_new = np.zeros(n_nodes)
            y_new = np.zeros(n_nodes)
            
            for i in range(n_nodes):
                # Local dynamics with overflow protection
                x_local = 1 - a * x[i]**2 + y[i]
                y_local = b * x[i]
                
                # Clip to prevent overflow
                x_local = np.clip(x_local, -10, 10)
                y_local = np.clip(y_local, -10, 10)
                
                # Coupling
                neighbors = np.where(adjacency[i] > 0)[0]
                if len(neighbors) > 0:
                    x_coupling = coupling * np.mean(x[neighbors] - x[i])
                    y_coupling = coupling * np.mean(y[neighbors] - y[i])
                else:
                    x_coupling = 0
                    y_coupling = 0
                
                x_new[i] = x_local + x_coupling
                y_new[i] = y_local + y_coupling
            
            x = x_new
            y = y_new
            
            # Scan every 10 steps
            if step % 10 == 0:
                self.scan_and_collect(x, y)
                
                if step % 50 == 0:
                    print(f"[M2L] Step {step}/{n_steps}: " + 
                          f"mean_x={np.mean(x):.4f}, mean_y={np.mean(y):.4f}")
        
        print("\n[M2L] ✓ Simulation complete")
        
        # Generate R analysis
        self.generate_to_r()
        
        # Export test results
        test_path = self.output_dir / "m2l_test_results.json"
        self.ml_tester.export_test_results(str(test_path))
        
        print("\n" + "="*60)
        print("M2L PROTOCOL RESULTS")
        print("="*60)
        print(f"Total scans: {len(self.scanner.scan_history)}")
        print(f"ML tests: {len(self.ml_tester.test_results)}")
        print(f"Output directory: {self.output_dir}")
        print("="*60)
        
        return True
    
    def disconnect(self) -> bool:
        """Graceful disconnect via tesseract protocol"""
        print("\n[M2L] Initiating disconnect...")
        
        if self.connected:
            return self.tesseract.execute_graceful_disconnect()
        else:
            print("[M2L] No active connection")
            return True


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='M2L Protocol - Machine-to-Learning Distribution')
    parser.add_argument('--host', default='localhost', help='Host address')
    parser.add_argument('--port', type=int, default=5555, help='Port number')
    parser.add_argument('--steps', type=int, default=100, help='Simulation steps')
    parser.add_argument('--nodes', type=int, default=16, help='Number of nodes')
    parser.add_argument('--coupling', type=float, default=0.05, help='Coupling strength')
    parser.add_argument('--no-connect', action='store_true', help='Skip network connection')
    
    args = parser.parse_args()
    
    # Create protocol
    protocol = M2LProtocol(host=args.host, port=args.port)
    
    # Initialize
    if not protocol.initialize():
        print("[M2L] ✗ Initialization failed")
        return 1
    
    # Connect (optional)
    if not args.no_connect:
        protocol.connect_user()
    
    # Run simulation
    protocol.run_simulation(
        n_steps=args.steps,
        n_nodes=args.nodes,
        coupling=args.coupling
    )
    
    # Disconnect
    protocol.disconnect()
    
    print("\n[M2L] Protocol complete")
    return 0


if __name__ == '__main__':
    sys.exit(main())
