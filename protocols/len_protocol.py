#!/usr/bin/env python3
"""
LEN Protocol - Login-Encryption-Network Security Layer

Integrates with NCOMM architecture:
1. Network Layer: Secure connection establishment over Tesseract
2. Data Layer: Encryption, authentication, and session management
3. Analysis Layer: Security auditing, intrusion detection, access logs

Features:
- User authentication with token-based sessions
- End-to-end encryption for data channels
- Security event logging and analysis
- Integration with M2L and Tesseract protocols
"""

import socket
import json
import hashlib
import secrets
import time
import hmac
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from enum import Enum


class SecurityLevel(Enum):
    """Security levels for LEN protocol"""
    PUBLIC = 0
    AUTHENTICATED = 1
    ENCRYPTED = 2
    VERIFIED = 3


class EventType(Enum):
    """Security event types"""
    LOGIN_ATTEMPT = "login_attempt"
    LOGIN_SUCCESS = "login_success"
    LOGIN_FAILURE = "login_failure"
    LOGOUT = "logout"
    TOKEN_ISSUED = "token_issued"
    TOKEN_EXPIRED = "token_expired"
    ENCRYPTION_START = "encryption_start"
    INTRUSION_DETECTED = "intrusion_detected"
    ACCESS_DENIED = "access_denied"


@dataclass
class User:
    """User credential structure"""
    username: str
    password_hash: str
    salt: str
    created_at: str
    last_login: Optional[str] = None
    security_level: int = SecurityLevel.AUTHENTICATED.value
    failed_attempts: int = 0


@dataclass
class Session:
    """Active session structure"""
    session_id: str
    username: str
    token: str
    created_at: str
    expires_at: str
    security_level: int
    ip_address: str
    active: bool = True


@dataclass
class SecurityEvent:
    """Security audit event"""
    timestamp: str
    event_type: str
    username: Optional[str]
    ip_address: str
    success: bool
    details: Dict[str, Any]


class UserDatabase:
    """Simple file-based user database"""
    
    def __init__(self, db_path: str = "len_users.json"):
        self.db_path = Path(db_path)
        self.users: Dict[str, User] = {}
        self.load()
    
    def load(self):
        """Load users from file"""
        if self.db_path.exists():
            try:
                with open(self.db_path, 'r') as f:
                    data = json.load(f)
                    self.users = {
                        username: User(**user_data)
                        for username, user_data in data.items()
                    }
                print(f"[LEN:UserDB] Loaded {len(self.users)} users")
            except Exception as e:
                print(f"[LEN:UserDB] Load error: {e}")
                self.users = {}
    
    def save(self):
        """Save users to file"""
        try:
            data = {
                username: asdict(user)
                for username, user in self.users.items()
            }
            with open(self.db_path, 'w') as f:
                json.dump(data, f, indent=2)
            return True
        except Exception as e:
            print(f"[LEN:UserDB] Save error: {e}")
            return False
    
    def create_user(self, username: str, password: str, 
                   security_level: SecurityLevel = SecurityLevel.AUTHENTICATED) -> bool:
        """Create new user"""
        if username in self.users:
            return False
        
        # Generate salt and hash password
        salt = secrets.token_hex(16)
        password_hash = self._hash_password(password, salt)
        
        user = User(
            username=username,
            password_hash=password_hash,
            salt=salt,
            created_at=datetime.now().isoformat(),
            security_level=security_level.value
        )
        
        self.users[username] = user
        self.save()
        print(f"[LEN:UserDB] Created user: {username}")
        return True
    
    def verify_password(self, username: str, password: str) -> bool:
        """Verify user password"""
        if username not in self.users:
            return False
        
        user = self.users[username]
        password_hash = self._hash_password(password, user.salt)
        return hmac.compare_digest(password_hash, user.password_hash)
    
    def update_login(self, username: str, success: bool):
        """Update login statistics"""
        if username not in self.users:
            return
        
        user = self.users[username]
        if success:
            user.last_login = datetime.now().isoformat()
            user.failed_attempts = 0
        else:
            user.failed_attempts += 1
        
        self.save()
    
    def is_locked(self, username: str, max_attempts: int = 5) -> bool:
        """Check if user account is locked due to failed attempts"""
        if username not in self.users:
            return False
        return self.users[username].failed_attempts >= max_attempts
    
    @staticmethod
    def _hash_password(password: str, salt: str) -> str:
        """Hash password with salt using SHA-256"""
        return hashlib.sha256(f"{password}{salt}".encode()).hexdigest()


class SessionManager:
    """Manages active user sessions"""
    
    def __init__(self, session_duration_hours: int = 24):
        self.sessions: Dict[str, Session] = {}
        self.session_duration = timedelta(hours=session_duration_hours)
    
    def create_session(self, username: str, ip_address: str, 
                      security_level: SecurityLevel) -> Session:
        """Create new session"""
        session_id = secrets.token_urlsafe(32)
        token = secrets.token_urlsafe(64)
        now = datetime.now()
        
        session = Session(
            session_id=session_id,
            username=username,
            token=token,
            created_at=now.isoformat(),
            expires_at=(now + self.session_duration).isoformat(),
            security_level=security_level.value,
            ip_address=ip_address
        )
        
        self.sessions[session_id] = session
        print(f"[LEN:Session] Created session for {username} (level={security_level.name})")
        return session
    
    def validate_session(self, session_id: str, token: str) -> Optional[Session]:
        """Validate session token"""
        if session_id not in self.sessions:
            return None
        
        session = self.sessions[session_id]
        
        # Check if expired
        if datetime.fromisoformat(session.expires_at) < datetime.now():
            session.active = False
            return None
        
        # Verify token
        if not hmac.compare_digest(session.token, token):
            return None
        
        return session if session.active else None
    
    def end_session(self, session_id: str):
        """End active session"""
        if session_id in self.sessions:
            self.sessions[session_id].active = False
            print(f"[LEN:Session] Ended session: {session_id[:16]}...")
    
    def cleanup_expired(self):
        """Remove expired sessions"""
        now = datetime.now()
        expired = [
            sid for sid, session in self.sessions.items()
            if datetime.fromisoformat(session.expires_at) < now
        ]
        for sid in expired:
            del self.sessions[sid]
        
        if expired:
            print(f"[LEN:Session] Cleaned {len(expired)} expired sessions")


class SecurityAuditor:
    """Security event logging and analysis"""
    
    def __init__(self, log_path: str = "len_security.log"):
        self.log_path = Path(log_path)
        self.events: List[SecurityEvent] = []
        self.alert_threshold = 5  # Failed attempts before alert
    
    def log_event(self, event_type: EventType, username: Optional[str], 
                  ip_address: str, success: bool, details: Dict[str, Any] = None):
        """Log security event"""
        event = SecurityEvent(
            timestamp=datetime.now().isoformat(),
            event_type=event_type.value,
            username=username,
            ip_address=ip_address,
            success=success,
            details=details or {}
        )
        
        self.events.append(event)
        self._write_to_log(event)
        
        # Check for intrusion patterns
        if event_type == EventType.LOGIN_FAILURE:
            self._check_intrusion_pattern(ip_address, username)
    
    def _write_to_log(self, event: SecurityEvent):
        """Write event to log file"""
        try:
            with open(self.log_path, 'a') as f:
                f.write(json.dumps(asdict(event)) + '\n')
        except Exception as e:
            print(f"[LEN:Audit] Log write error: {e}")
    
    def _check_intrusion_pattern(self, ip_address: str, username: Optional[str]):
        """Detect potential intrusion attempts"""
        # Check recent failures from same IP
        recent = [
            e for e in self.events[-20:]
            if e.ip_address == ip_address and 
               e.event_type == EventType.LOGIN_FAILURE.value
        ]
        
        if len(recent) >= self.alert_threshold:
            print(f"[LEN:Audit] ⚠ INTRUSION ALERT: {len(recent)} failed attempts from {ip_address}")
            self.log_event(
                EventType.INTRUSION_DETECTED,
                username,
                ip_address,
                False,
                {"failed_attempts": len(recent), "pattern": "brute_force"}
            )
    
    def get_recent_events(self, count: int = 10) -> List[SecurityEvent]:
        """Get recent security events"""
        return self.events[-count:]
    
    def export_audit_log(self, filepath: str) -> bool:
        """Export audit log to JSON"""
        try:
            with open(filepath, 'w') as f:
                json.dump([asdict(e) for e in self.events], f, indent=2)
            print(f"[LEN:Audit] Exported {len(self.events)} events to {filepath}")
            return True
        except Exception as e:
            print(f"[LEN:Audit] Export error: {e}")
            return False


class EncryptionLayer:
    """Simple encryption layer for data channels"""
    
    def __init__(self):
        self.active = False
        self.cipher_key: Optional[bytes] = None
    
    def initialize(self, session: Session) -> bool:
        """Initialize encryption for session"""
        # In production, use proper key exchange (e.g., Diffie-Hellman)
        # For demo, derive key from session token
        self.cipher_key = hashlib.sha256(session.token.encode()).digest()
        self.active = True
        print(f"[LEN:Encryption] Initialized for session {session.session_id[:16]}...")
        return True
    
    def encrypt(self, data: bytes) -> bytes:
        """Simple XOR encryption (use proper crypto in production)"""
        if not self.active or not self.cipher_key:
            return data
        
        # Simple XOR cipher for demonstration
        # In production, use AES-GCM or ChaCha20-Poly1305
        key_repeated = (self.cipher_key * (len(data) // len(self.cipher_key) + 1))[:len(data)]
        return bytes(a ^ b for a, b in zip(data, key_repeated))
    
    def decrypt(self, data: bytes) -> bytes:
        """Decrypt data (XOR is symmetric)"""
        return self.encrypt(data)  # XOR encryption is symmetric


class LENProtocol:
    """
    Main LEN Protocol Controller
    
    Integrates:
    - User authentication
    - Session management
    - Encryption layer
    - Security auditing
    - Integration with Tesseract and M2L protocols
    """
    
    def __init__(self, host: str = 'localhost', port: int = 5556):
        self.host = host
        self.port = port
        
        # Core components
        self.user_db = UserDatabase()
        self.session_mgr = SessionManager()
        self.auditor = SecurityAuditor()
        self.encryption = EncryptionLayer()
        
        # State
        self.current_session: Optional[Session] = None
        self.authenticated = False
        
        # Output directory
        self.output_dir = Path.cwd() / "len_output"
        self.output_dir.mkdir(exist_ok=True)
    
    def initialize(self) -> bool:
        """Initialize LEN protocol"""
        print("\n" + "="*60)
        print("LEN PROTOCOL INITIALIZATION")
        print("="*60)
        print(f"Host: {self.host}:{self.port}")
        print(f"Users: {len(self.user_db.users)}")
        print(f"Output: {self.output_dir}")
        print("="*60)
        
        # Create default admin user if none exist
        if not self.user_db.users:
            self.user_db.create_user("admin", "admin123", SecurityLevel.VERIFIED)
            print("[LEN] Created default admin user (username: admin, password: admin123)")
            print("[LEN] ⚠ CHANGE DEFAULT PASSWORD IN PRODUCTION!")
        
        print("[LEN] ✓ Initialization complete")
        return True
    
    def login(self, username: str, password: str, ip_address: str = "127.0.0.1") -> Tuple[bool, Optional[Session]]:
        """User login"""
        print(f"\n[LEN] Login attempt: {username} from {ip_address}")
        
        # Check if account is locked
        if self.user_db.is_locked(username):
            print(f"[LEN] ✗ Account locked: {username}")
            self.auditor.log_event(
                EventType.LOGIN_FAILURE,
                username,
                ip_address,
                False,
                {"reason": "account_locked"}
            )
            return False, None
        
        # Verify credentials
        if not self.user_db.verify_password(username, password):
            print(f"[LEN] ✗ Invalid credentials: {username}")
            self.user_db.update_login(username, False)
            self.auditor.log_event(
                EventType.LOGIN_FAILURE,
                username,
                ip_address,
                False,
                {"reason": "invalid_credentials"}
            )
            return False, None
        
        # Create session
        user = self.user_db.users[username]
        security_level = SecurityLevel(user.security_level)
        session = self.session_mgr.create_session(username, ip_address, security_level)
        
        # Update user record
        self.user_db.update_login(username, True)
        
        # Log success
        self.auditor.log_event(
            EventType.LOGIN_SUCCESS,
            username,
            ip_address,
            True,
            {"session_id": session.session_id, "security_level": security_level.name}
        )
        
        # Set current session
        self.current_session = session
        self.authenticated = True
        
        # Initialize encryption if high security
        if security_level in [SecurityLevel.ENCRYPTED, SecurityLevel.VERIFIED]:
            self.encryption.initialize(session)
            self.auditor.log_event(
                EventType.ENCRYPTION_START,
                username,
                ip_address,
                True,
                {"session_id": session.session_id}
            )
        
        print(f"[LEN] ✓ Login successful: {username} (level={security_level.name})")
        return True, session
    
    def logout(self):
        """User logout"""
        if not self.current_session:
            print("[LEN] No active session")
            return
        
        username = self.current_session.username
        session_id = self.current_session.session_id
        
        self.session_mgr.end_session(session_id)
        self.auditor.log_event(
            EventType.LOGOUT,
            username,
            self.current_session.ip_address,
            True,
            {"session_id": session_id}
        )
        
        self.current_session = None
        self.authenticated = False
        self.encryption.active = False
        
        print(f"[LEN] ✓ Logout successful: {username}")
    
    def validate_access(self, required_level: SecurityLevel = SecurityLevel.AUTHENTICATED) -> bool:
        """Validate current user has required security level"""
        if not self.authenticated or not self.current_session:
            print(f"[LEN] ✗ Access denied: Not authenticated")
            return False
        
        # Validate session is still valid
        validated = self.session_mgr.validate_session(
            self.current_session.session_id,
            self.current_session.token
        )
        
        if not validated:
            print(f"[LEN] ✗ Access denied: Invalid session")
            self.authenticated = False
            return False
        
        # Check security level
        if validated.security_level < required_level.value:
            print(f"[LEN] ✗ Access denied: Insufficient security level")
            self.auditor.log_event(
                EventType.ACCESS_DENIED,
                validated.username,
                validated.ip_address,
                False,
                {"required": required_level.name, "current": SecurityLevel(validated.security_level).name}
            )
            return False
        
        return True
    
    def secure_send(self, data: bytes) -> bytes:
        """Send data with encryption if enabled"""
        if self.encryption.active:
            return self.encryption.encrypt(data)
        return data
    
    def secure_receive(self, data: bytes) -> bytes:
        """Receive and decrypt data if encryption enabled"""
        if self.encryption.active:
            return self.encryption.decrypt(data)
        return data
    
    def get_security_report(self) -> Dict[str, Any]:
        """Generate security status report"""
        return {
            "timestamp": datetime.now().isoformat(),
            "authenticated": self.authenticated,
            "current_user": self.current_session.username if self.current_session else None,
            "security_level": SecurityLevel(self.current_session.security_level).name if self.current_session else None,
            "encryption_active": self.encryption.active,
            "total_users": len(self.user_db.users),
            "active_sessions": sum(1 for s in self.session_mgr.sessions.values() if s.active),
            "recent_events": len(self.auditor.events[-10:])
        }
    
    def export_security_data(self) -> bool:
        """Export all security data"""
        print("\n[LEN] Exporting security data...")
        
        # Export audit log
        audit_path = self.output_dir / f"len_audit_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        self.auditor.export_audit_log(str(audit_path))
        
        # Export security report
        report_path = self.output_dir / "len_security_report.json"
        with open(report_path, 'w') as f:
            json.dump(self.get_security_report(), f, indent=2)
        
        print(f"[LEN] ✓ Security data exported to {self.output_dir}")
        return True


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='LEN Protocol - Login-Encryption-Network')
    parser.add_argument('--host', default='localhost', help='Host address')
    parser.add_argument('--port', type=int, default=5556, help='Port number')
    parser.add_argument('--create-user', nargs=2, metavar=('USERNAME', 'PASSWORD'), 
                       help='Create new user')
    parser.add_argument('--demo', action='store_true', help='Run demo scenario')
    
    args = parser.parse_args()
    
    # Initialize protocol
    protocol = LENProtocol(host=args.host, port=args.port)
    protocol.initialize()
    
    # Create user if requested
    if args.create_user:
        username, password = args.create_user
        protocol.user_db.create_user(username, password, SecurityLevel.AUTHENTICATED)
        print(f"\n[LEN] User created: {username}")
    
    # Run demo if requested
    if args.demo:
        print("\n" + "="*60)
        print("LEN PROTOCOL DEMO")
        print("="*60)
        
        # Demo: Successful login
        print("\n>>> Scenario 1: Successful Login")
        success, session = protocol.login("admin", "admin123", "192.168.1.100")
        if success:
            print(f"Session ID: {session.session_id[:16]}...")
            print(f"Token: {session.token[:32]}...")
            print(f"Security Level: {SecurityLevel(session.security_level).name}")
        
        # Demo: Access validation
        print("\n>>> Scenario 2: Access Validation")
        if protocol.validate_access(SecurityLevel.AUTHENTICATED):
            print("[LEN] ✓ Access granted")
        
        # Demo: Security report
        print("\n>>> Scenario 3: Security Report")
        report = protocol.get_security_report()
        print(json.dumps(report, indent=2))
        
        # Demo: Failed login attempts
        print("\n>>> Scenario 4: Failed Login Attempts")
        for i in range(3):
            protocol.login("admin", "wrongpass", "10.0.0.50")
        
        # Demo: Logout
        print("\n>>> Scenario 5: Logout")
        protocol.logout()
        
        # Export data
        protocol.export_security_data()
        
        print("\n" + "="*60)
        print("DEMO COMPLETE")
        print("="*60)
        print(f"Check {protocol.output_dir} for security logs")
    
    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main())
