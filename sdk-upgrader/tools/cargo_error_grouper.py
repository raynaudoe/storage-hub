#!/usr/bin/env python3
"""
Parse cargo check JSON output and group errors by primary symbol.
This is used by the orchestrator to create focused work units for agents.
"""

import json
import subprocess
import re
from collections import defaultdict
from datetime import datetime, timezone

def extract_primary_symbol(message):
    """Extract the primary symbol from an error message."""
    
    # Check for Rust version errors first
    rust_version_patterns = [
        r"requires rustc \d+\.\d+",
        r"cannot be built because it requires rustc",
        r"package.*requires rustc.*or newer",
        r"error: package.*requires rustc",
        r"rustc version is \d+\.\d+.*but.*requires",
        # Cargo feature errors
        r"requires the Cargo feature.*not stabilized",
        r"feature is not stabilized in this version of Cargo",
        r"edition\d{4}.*not stabilized"
    ]
    
    for pattern in rust_version_patterns:
        if re.search(pattern, message, re.IGNORECASE):
            return "rust_version_incompatibility"
    
    # Common patterns in Rust errors
    patterns = [
        # Trait not found: "cannot find trait `Block` in this scope"
        r"cannot find (?:trait|type|value|macro|function) `([^`]+)`",
        # Type mismatch: "expected struct `Weight`, found struct `OldWeight`"
        r"expected (?:struct|enum|type) `([^`]+)`",
        # Method not found: "no method named `checked_add` found"
        r"no method named `([^`]+)` found",
        # Trait bound: "the trait bound `T: Config` is not satisfied"
        r"the trait bound `[^:]+: ([^`]+)` is not satisfied",
        # Module not found: "unresolved import `frame_support::traits::Foo`"
        r"unresolved import `([^`]+)`",
        # Missing field: "missing field `foo` in initializer"
        r"missing field `([^`]+)`",
        # Wrong number of arguments
        r"(?:function|method) `([^`]+)` (?:takes|expects)",
    ]
    
    for pattern in patterns:
        match = re.search(pattern, message)
        if match:
            symbol = match.group(1)
            # For imports, get the last component
            if '::' in symbol:
                return symbol.split('::')[-1]
            return symbol
    
    # Fallback: try to extract any code-like symbol
    code_match = re.search(r'`([^`]+)`', message)
    if code_match:
        return code_match.group(1).split('::')[-1]
    
    return "unknown"

def parse_cargo_errors(json_output):
    """Parse cargo check JSON output and extract errors."""
    errors = []
    
    for line in json_output.strip().split('\n'):
        if not line:
            continue
            
        try:
            entry = json.loads(line)
            
            # We only care about compiler messages
            if entry.get('reason') != 'compiler-message':
                continue
                
            message = entry.get('message', {})
            
            # Only process errors (not warnings)
            if message.get('level') != 'error':
                continue
                
            # Extract relevant information
            error_info = {
                'message': message.get('message', ''),
                'code': message.get('code', {}).get('code', 'unknown'),
                'file': None,
                'line': None,
                'column': None,
            }
            
            # Get primary span information
            spans = message.get('spans', [])
            for span in spans:
                if span.get('is_primary'):
                    error_info['file'] = span.get('file_name')
                    error_info['line'] = span.get('line_start')
                    error_info['column'] = span.get('column_start')
                    break
            
            # Only include errors with file information
            if error_info['file']:
                errors.append(error_info)
                
        except json.JSONDecodeError:
            continue
    
    return errors

def group_errors_by_symbol(errors):
    """Group errors by their primary symbol."""
    groups = defaultdict(list)
    
    for error in errors:
        symbol = extract_primary_symbol(error['message'])
        groups[symbol].append(error)
    
    return dict(groups)

def create_error_groups(grouped_errors, max_errors_per_group=5):
    """Create error groups for the orchestrator."""
    error_groups = []
    group_id = 1
    
    # Sort by number of errors (descending) to prioritize high-impact symbols
    sorted_symbols = sorted(grouped_errors.items(), key=lambda x: len(x[1]), reverse=True)
    
    for symbol, errors in sorted_symbols:
        # Split large error sets into multiple groups
        for i in range(0, len(errors), max_errors_per_group):
            error_batch = errors[i:i + max_errors_per_group]
            
            error_groups.append({
                'id': f'error_group_{group_id:03d}',
                'symbol': symbol,
                'error_count': len(error_batch),
                'errors': error_batch,
                'status': 'pending',
                'files': list(set(e['file'] for e in error_batch))
            })
            group_id += 1
    
    return error_groups

def run_cargo_check():
    """Run cargo check and return JSON output."""
    cmd = ['cargo', 'check', '--workspace', '--message-format=json']
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout

def save_error_groups(error_groups, status_file):
    """Save error groups to status file."""
    status = {
        'strategy': 'error_based_sequential',
        'created_at': datetime.now(timezone.utc).isoformat(),
        'total_errors': sum(g['error_count'] for g in error_groups),
        'error_groups': error_groups,
        'completed_groups': 0,
        'iteration': 1
    }
    
    with open(status_file, 'w') as f:
        json.dump(status, f, indent=2)
    
    return status

def update_status_file(status_file, error_groups):
    """Update existing status file with new error groups."""
    try:
        with open(status_file, 'r') as f:
            status = json.load(f)
    except FileNotFoundError:
        # Create new status if doesn't exist
        status = {
            'strategy': 'error_based_sequential',
            'created_at': datetime.now(timezone.utc).isoformat(),
            'iteration': 0,
            'completed_groups': 0
        }
    
    # Update with new error groups
    status['error_groups'] = error_groups
    status['total_errors'] = sum(g['error_count'] for g in error_groups)
    status['last_check'] = datetime.now(timezone.utc).isoformat()
    
    with open(status_file, 'w') as f:
        json.dump(status, f, indent=2)
    
    return status

def main():
    """Main function with command-line interface."""
    import sys
    import argparse
    
    parser = argparse.ArgumentParser(description='Parse and group cargo check errors')
    parser.add_argument('command', choices=['parse', 'group', 'test'], 
                        help='Command to run')
    parser.add_argument('--max-per-group', type=int, default=5,
                        help='Maximum errors per group (default: 5)')
    parser.add_argument('--status-file', default='status.json',
                        help='Status file path (default: status.json)')
    parser.add_argument('--input', '-i', help='Input file (default: stdin)')
    
    args = parser.parse_args()
    
    if args.command == 'parse':
        # Read JSON from stdin or file
        if args.input:
            with open(args.input, 'r') as f:
                json_output = f.read()
        else:
            json_output = sys.stdin.read()
        
        errors = parse_cargo_errors(json_output)
        print(json.dumps({
            'error_count': len(errors),
            'errors': errors
        }, indent=2))
    
    elif args.command == 'group':
        # Read parsed errors from stdin
        parsed_data = json.loads(sys.stdin.read())
        errors = parsed_data.get('errors', [])
        
        if not errors:
            print(json.dumps({
                'error_count': 0,
                'groups': []
            }, indent=2))
            return
        
        grouped = group_errors_by_symbol(errors)
        error_groups = create_error_groups(grouped, args.max_per_group)
        
        # Update status file
        update_status_file(args.status_file, error_groups)
        
        print(json.dumps({
            'error_count': len(errors),
            'group_count': len(error_groups),
            'groups': error_groups
        }, indent=2))
    
    elif args.command == 'test':
        # Original test functionality
        print("Running cargo check...")
        json_output = run_cargo_check()
        
        print("Parsing errors...")
        errors = parse_cargo_errors(json_output)
        print(f"Found {len(errors)} errors")
        
        if not errors:
            print("No errors found!")
            return
        
        print("\nGrouping errors by symbol...")
        grouped = group_errors_by_symbol(errors)
        print(f"Created {len(grouped)} symbol groups")
        
        # Show top symbols
        print("\nTop error symbols:")
        for symbol, errs in sorted(grouped.items(), key=lambda x: len(x[1]), reverse=True)[:10]:
            print(f"  {symbol}: {len(errs)} errors")
        
        print("\nCreating error groups...")
        error_groups = create_error_groups(grouped, args.max_per_group)
        print(f"Created {len(error_groups)} error groups")
        
        # Save to status file
        update_status_file(args.status_file, error_groups)
        print(f"\nSaved to {args.status_file}")

if __name__ == "__main__":
    main()