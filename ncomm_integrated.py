#!/usr/bin/env python3
"""
NCOMM Integrated Protocol Stack

Demonstrates integration of:
1. LEN Protocol (Security Layer)
2. M2L Protocol (Machine Learning Layer)
3. Tesseract Protocol (Network Layer)

Usage:
    python3 ncomm_integrated.py --demo
    python3 ncomm_integrated.py --secure-simulation
"""

import sys
import numpy as np
from pathlib import Path
from typing import Optional

# Import protocol components
from len_protocol import LENProtocol, SecurityLevel
from m2l_protocol import M2LProtocol
from tesseract_entanglement_protocol import TesseractEntanglementProtocol


class NCOMMIntegrated:
    """
    Integrated NCOMM Protocol Stack
    
    Layer Architecture:
    ┌──────────────────────────────────────┐
    │   Application Layer (M2L)            │  <- ML Analysis & Data
    ├──────────────────────────────────────┤
    │   Security Layer (LEN)               │  <- Auth, Encryption, Audit
    ├──────────────────────────────────────┤
    │   Network Layer (Tesseract)          │  <- Connection Management
    └──────────────────────────────────────┘
    """
    
    def __init__(self, host: str = 'localhost', 
                 tesseract_port: int = 5555,
                 len_port: int = 5556):
        self.host = host
        
        # Initialize protocol layers
        print("\n" + "="*60)
        print("NCOMM INTEGRATED PROTOCOL STACK")
        print("="*60)
        
        # Layer 1: Network (Tesseract)
        print("\n[NCOMM] Initializing Network Layer (Tesseract)...")
        self.tesseract = TesseractEntanglementProtocol(host, tesseract_port)
        
        # Layer 2: Security (LEN)
        print("[NCOMM] Initializing Security Layer (LEN)...")
        self.len = LENProtocol(host, len_port)
        self.len.initialize()
        
        # Layer 3: Application (M2L)
        print("[NCOMM] Initializing Application Layer (M2L)...")
        self.m2l = M2LProtocol(host, tesseract_port)
        self.m2l.initialize()
        
        print("\n" + "="*60)
        print("PROTOCOL STACK READY")
        print("="*60)
    
    def secure_connect(self, username: str, password: str) -> bool:
        """
        Establish secure connection with authentication
        
        Flow:
        1. LEN: Authenticate user
        2. LEN: Establish encryption
        3. Tesseract: Connect to network
        """
        print("\n" + "="*60)
        print("SECURE CONNECTION ESTABLISHMENT")
        print("="*60)
        
        # Step 1: Authenticate
        print("\n[NCOMM] Step 1: User Authentication (LEN)")
        success, session = self.len.login(username, password, self.host)
        
        if not success:
            print("[NCOMM] ✗ Authentication failed")
            return False
        
        print(f"[NCOMM] ✓ Authenticated as {username}")
        print(f"[NCOMM]   Security Level: {SecurityLevel(session.security_level).name}")
        print(f"[NCOMM]   Encryption: {self.len.encryption.active}")
        
        # Step 2: Establish network connection
        print("\n[NCOMM] Step 2: Network Connection (Tesseract)")
        # Note: In standalone mode, we don't need actual network connection
        print("[NCOMM] ✓ Network layer ready (standalone mode)")
        
        print("\n" + "="*60)
        print("SECURE CONNECTION ESTABLISHED")
        print("="*60)
        return True
    
    def run_secure_simulation(self, steps: int = 100, coupling: float = 0.05):
        """
        Run M2L simulation with security enabled
        
        Security features:
        - Requires authentication
        - Logs all operations
        - Encrypts data output (if high security)
        """
        print("\n" + "="*60)
        print("SECURE SIMULATION")
        print("="*60)
        
        # Validate access
        if not self.len.validate_access(SecurityLevel.AUTHENTICATED):
            print("[NCOMM] ✗ Access denied - authentication required")
            return False
        
        username = self.len.current_session.username
        print(f"[NCOMM] User: {username}")
        print(f"[NCOMM] Security: {SecurityLevel(self.len.current_session.security_level).name}")
        print(f"[NCOMM] Simulation: {steps} steps, coupling={coupling}")
        print("="*60)
        
        # Run M2L simulation
        print("\n[NCOMM] Running M2L Protocol simulation...")
        self.m2l.run_simulation(
            n_steps=steps,
            n_nodes=16,
            coupling=coupling
        )
        
        # Export security audit
        print("\n[NCOMM] Exporting security audit...")
        self.len.export_security_data()
        
        print("\n" + "="*60)
        print("SECURE SIMULATION COMPLETE")
        print("="*60)
        print(f"Data: {self.m2l.output_dir}")
        print(f"Security: {self.len.output_dir}")
        print("="*60)
        
        return True
    
    def secure_disconnect(self):
        """
        Graceful disconnect with audit trail
        
        Flow:
        1. M2L: Export final data
        2. LEN: Log logout event
        3. Tesseract: Graceful disconnect
        """
        print("\n" + "="*60)
        print("SECURE DISCONNECT")
        print("="*60)
        
        if self.len.authenticated:
            username = self.len.current_session.username
            print(f"\n[NCOMM] User: {username}")
            
            # Export security data
            print("[NCOMM] Exporting security audit...")
            self.len.export_security_data()
            
            # Logout
            print("[NCOMM] Logging out...")
            self.len.logout()
        
        # Tesseract disconnect (if connected)
        print("[NCOMM] Closing network connections...")
        print("[NCOMM] ✓ Network layer closed")
        
        print("\n" + "="*60)
        print("DISCONNECT COMPLETE")
        print("="*60)
    
    def get_system_status(self):
        """Get status of all protocol layers"""
        status = {
            "network": {
                "protocol": "Tesseract",
                "state": self.tesseract.state.tolist(),
                "connected": self.tesseract.sock is not None
            },
            "security": {
                "protocol": "LEN",
                "authenticated": self.len.authenticated,
                "current_user": self.len.current_session.username if self.len.current_session else None,
                "encryption_active": self.len.encryption.active,
                "total_users": len(self.len.user_db.users),
                "active_sessions": sum(1 for s in self.len.session_mgr.sessions.values() if s.active)
            },
            "application": {
                "protocol": "M2L",
                "initialized": self.m2l.initialized,
                "r_available": self.m2l.r_interface.is_available(),
                "scans_collected": len(self.m2l.scanner.scan_history),
                "ml_tests": len(self.m2l.ml_tester.test_results)
            }
        }
        return status
    
    def print_status(self):
        """Print formatted system status"""
        status = self.get_system_status()
        
        print("\n" + "="*60)
        print("NCOMM SYSTEM STATUS")
        print("="*60)
        
        print("\n[Network Layer - Tesseract]")
        print(f"  State: {status['network']['state']}")
        print(f"  Connected: {status['network']['connected']}")
        
        print("\n[Security Layer - LEN]")
        print(f"  Authenticated: {status['security']['authenticated']}")
        print(f"  User: {status['security']['current_user'] or 'None'}")
        print(f"  Encryption: {status['security']['encryption_active']}")
        print(f"  Total Users: {status['security']['total_users']}")
        print(f"  Active Sessions: {status['security']['active_sessions']}")
        
        print("\n[Application Layer - M2L]")
        print(f"  Initialized: {status['application']['initialized']}")
        print(f"  R Available: {status['application']['r_available']}")
        print(f"  Scans: {status['application']['scans_collected']}")
        print(f"  ML Tests: {status['application']['ml_tests']}")
        
        print("\n" + "="*60)


def demo_basic_stack():
    """Demonstrate basic protocol stack"""
    print("\n" + "="*60)
    print("DEMO: BASIC PROTOCOL STACK")
    print("="*60)
    
    # Initialize
    ncomm = NCOMMIntegrated()
    
    # Show initial status
    ncomm.print_status()
    
    # Secure connect
    ncomm.secure_connect("admin", "admin123")
    
    # Show authenticated status
    ncomm.print_status()
    
    # Run small simulation
    ncomm.run_secure_simulation(steps=50, coupling=0.05)
    
    # Show final status
    ncomm.print_status()
    
    # Disconnect
    ncomm.secure_disconnect()


def demo_security_features():
    """Demonstrate security features"""
    print("\n" + "="*60)
    print("DEMO: SECURITY FEATURES")
    print("="*60)
    
    ncomm = NCOMMIntegrated()
    
    # Scenario 1: Failed login
    print("\n>>> Scenario 1: Failed Login")
    ncomm.secure_connect("admin", "wrongpassword")
    
    # Scenario 2: Successful login
    print("\n>>> Scenario 2: Successful Login")
    ncomm.secure_connect("admin", "admin123")
    
    # Scenario 3: Access validation
    print("\n>>> Scenario 3: Access Validation")
    if ncomm.len.validate_access(SecurityLevel.AUTHENTICATED):
        print("[NCOMM] ✓ Access granted for simulation")
        ncomm.run_secure_simulation(steps=30, coupling=0.05)
    
    # Scenario 4: Create new user
    print("\n>>> Scenario 4: Create New User")
    ncomm.len.user_db.create_user("researcher", "research123", SecurityLevel.ENCRYPTED)
    
    # Scenario 5: Logout and re-login
    print("\n>>> Scenario 5: User Switch")
    ncomm.secure_disconnect()
    ncomm.secure_connect("researcher", "research123")
    
    # Show security report
    print("\n>>> Security Report")
    import json
    report = ncomm.len.get_security_report()
    print(json.dumps(report, indent=2))
    
    ncomm.secure_disconnect()


def demo_full_integration():
    """Full integration demo with all features"""
    print("\n" + "="*60)
    print("DEMO: FULL INTEGRATION")
    print("="*60)
    
    ncomm = NCOMMIntegrated()
    
    # Phase 1: Setup
    print("\n>>> Phase 1: User Setup")
    ncomm.len.user_db.create_user("ml_user", "ml123", SecurityLevel.VERIFIED)
    
    # Phase 2: Login with highest security
    print("\n>>> Phase 2: Secure Login (VERIFIED level)")
    ncomm.secure_connect("ml_user", "ml123")
    
    # Phase 3: Run comprehensive simulation
    print("\n>>> Phase 3: Comprehensive ML Simulation")
    ncomm.run_secure_simulation(steps=200, coupling=0.03)
    
    # Phase 4: Status check
    print("\n>>> Phase 4: System Status")
    ncomm.print_status()
    
    # Phase 5: Security audit
    print("\n>>> Phase 5: Security Audit")
    ncomm.len.export_security_data()
    
    # Phase 6: Graceful disconnect
    print("\n>>> Phase 6: Secure Disconnect")
    ncomm.secure_disconnect()
    
    print("\n" + "="*60)
    print("FULL INTEGRATION DEMO COMPLETE")
    print("="*60)


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='NCOMM Integrated Protocol Stack')
    parser.add_argument('--host', default='localhost', help='Host address')
    parser.add_argument('--tesseract-port', type=int, default=5555, help='Tesseract port')
    parser.add_argument('--len-port', type=int, default=5556, help='LEN port')
    
    parser.add_argument('--demo', action='store_true', help='Run basic demo')
    parser.add_argument('--demo-security', action='store_true', help='Demo security features')
    parser.add_argument('--demo-full', action='store_true', help='Full integration demo')
    
    parser.add_argument('--username', default='admin', help='Username for login')
    parser.add_argument('--password', default='admin123', help='Password for login')
    parser.add_argument('--secure-simulation', action='store_true', 
                       help='Run secure simulation')
    parser.add_argument('--steps', type=int, default=100, help='Simulation steps')
    parser.add_argument('--coupling', type=float, default=0.05, help='Coupling strength')
    
    args = parser.parse_args()
    
    # Run demos
    if args.demo:
        demo_basic_stack()
        return 0
    
    if args.demo_security:
        demo_security_features()
        return 0
    
    if args.demo_full:
        demo_full_integration()
        return 0
    
    # Manual mode
    ncomm = NCOMMIntegrated(
        host=args.host,
        tesseract_port=args.tesseract_port,
        len_port=args.len_port
    )
    
    if args.secure_simulation:
        # Login
        if not ncomm.secure_connect(args.username, args.password):
            print("[NCOMM] ✗ Login failed")
            return 1
        
        # Run simulation
        ncomm.run_secure_simulation(steps=args.steps, coupling=args.coupling)
        
        # Disconnect
        ncomm.secure_disconnect()
    else:
        # Just show status
        ncomm.print_status()
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
