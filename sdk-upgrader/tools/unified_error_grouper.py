#!/usr/bin/env python3
"""
Unified error grouper for cargo check (JSON) and cargo test (text) outputs.
Creates focused work units for AI agents to fix compilation and test errors.
"""

import json
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone


class ErrorGrouper:
    """Base class for error grouping logic."""
    
    def __init__(self, max_per_group=5):
        self.max_per_group = max_per_group
    
    def create_groups(self, items, group_type):
        """Create groups from items."""
        groups = []
        group_id = 1
        
        for key, items_list in items:
            for i in range(0, len(items_list), self.max_per_group):
                batch = items_list[i:i + self.max_per_group]
                
                if group_type == "error":
                    groups.append({
                        'id': f'error_group_{group_id:03d}',
                        'symbol': key,
                        'error_count': len(batch),
                        'errors': batch,
                        'status': 'pending',
                        'files': list(set(e['file'] for e in batch if e.get('file')))
                    })
                elif group_type == "test":
                    groups.append({
                        'id': f'test_group_{group_id:03d}',
                        'module': key,
                        'test_count': len(batch),
                        'tests': [t['test_name'] for t in batch],
                        'status': 'pending',
                        'failures': batch
                    })
                
                group_id += 1
        
        return groups


class CargoCheckParser(ErrorGrouper):
    """Parser for cargo check JSON output."""
    
    def parse(self, json_input):
        """Parse cargo check JSON output and return grouped errors."""
        errors = []
        
        for line in json_input.strip().split('\n'):
            if not line:
                continue
                
            try:
                entry = json.loads(line)
                
                if entry.get('reason') != 'compiler-message':
                    continue
                    
                message = entry.get('message', {})
                
                if message.get('level') != 'error':
                    continue
                    
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
                
                if error_info['file']:
                    errors.append(error_info)
                    
            except json.JSONDecodeError:
                continue
        
        # Group by symbol
        grouped = defaultdict(list)
        for error in errors:
            symbol = self._extract_symbol(error['message'])
            grouped[symbol].append(error)
        
        # Sort by frequency (high impact first)
        sorted_groups = sorted(grouped.items(), key=lambda x: len(x[1]), reverse=True)
        
        return {
            'error_count': len(errors),
            'error_groups': self.create_groups(sorted_groups, 'error')
        }
    
    def _extract_symbol(self, message):
        """Extract the primary symbol from an error message."""
        # Check for Rust version errors first
        rust_version_patterns = [
            r"requires rustc \d+\.\d+",
            r"cannot be built because it requires rustc",
            r"package.*requires rustc.*or newer",
            r"rustc version is \d+\.\d+.*but.*requires",
            r"requires the Cargo feature.*not stabilized",
            r"edition\d{4}.*not stabilized"
        ]
        
        for pattern in rust_version_patterns:
            if re.search(pattern, message, re.IGNORECASE):
                return "rust_version_incompatibility"
        
        # Common error patterns
        patterns = [
            r"cannot find (?:trait|type|value|macro|function) `([^`]+)`",
            r"expected (?:struct|enum|type) `([^`]+)`",
            r"no method named `([^`]+)` found",
            r"the trait bound `[^:]+: ([^`]+)` is not satisfied",
            r"unresolved import `([^`]+)`",
            r"missing field `([^`]+)`",
            r"(?:function|method) `([^`]+)` (?:takes|expects)",
        ]
        
        for pattern in patterns:
            match = re.search(pattern, message)
            if match:
                symbol = match.group(1)
                if '::' in symbol:
                    return symbol.split('::')[-1]
                return symbol
        
        # Fallback
        code_match = re.search(r'`([^`]+)`', message)
        if code_match:
            return code_match.group(1).split('::')[-1]
        
        return "unknown"


class CargoTestParser(ErrorGrouper):
    """Parser for cargo test text output."""
    
    def parse(self, text_input):
        """Parse cargo test output and return grouped failures."""
        failures = []
        lines = text_input.strip().split('\n')
        i = 0
        
        while i < len(lines):
            line = lines[i]
            
            # Look for test failure patterns: "test module::path::test_name ... FAILED"
            if re.match(r'^test\s+\S+.*\s+FAILED$', line):
                match = re.match(r'^test\s+(\S+)\s+.*\s+FAILED$', line)
                if match:
                    test_path = match.group(1)
                    parts = test_path.split('::')
                    
                    if len(parts) >= 2:
                        module = parts[0]
                        
                        failure_info = {
                            'test_path': test_path,
                            'module': module,
                            'test_name': test_path,
                            'line': i + 1,
                            'failure_output': []
                        }
                        
                        # Capture failure output
                        j = i + 1
                        capturing = False
                        while j < len(lines):
                            if lines[j].startswith('---- ') and ' stdout ----' in lines[j]:
                                capturing = True
                            elif lines[j].startswith('failures:'):
                                break
                            elif capturing:
                                failure_info['failure_output'].append(lines[j])
                            j += 1
                        
                        failures.append(failure_info)
            
            i += 1
        
        # Group by module
        grouped = defaultdict(list)
        for failure in failures:
            grouped[failure['module']].append(failure)
        
        # Sort by frequency
        sorted_groups = sorted(grouped.items(), key=lambda x: len(x[1]), reverse=True)
        
        return {
            'failure_count': len(failures),
            'test_groups': self.create_groups(sorted_groups, 'test')
        }


def main():
    """Main entry point with command-line interface."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Unified error grouper for cargo check and test')
    parser.add_argument('mode', choices=['check', 'test'], 
                        help='Mode: check for cargo check errors, test for cargo test failures')
    parser.add_argument('--max-per-group', type=int, default=5,
                        help='Maximum items per group (default: 5)')
    parser.add_argument('--status-file', help='Status file to update (for orchestrator integration)')
    
    args = parser.parse_args()
    
    # Read input from stdin
    input_data = sys.stdin.read()
    
    if args.mode == 'check':
        processor = CargoCheckParser(args.max_per_group)
        result = processor.parse(input_data)
        
        # Update status file if provided
        if args.status_file:
            try:
                with open(args.status_file, 'r') as f:
                    status = json.load(f)
            except FileNotFoundError:
                status = {
                    'strategy': 'error_based_sequential',
                    'created_at': datetime.now(timezone.utc).isoformat(),
                }
            
            status['error_groups'] = result['error_groups']
            status['total_errors'] = result['error_count']
            status['last_check'] = datetime.now(timezone.utc).isoformat()
            
            with open(args.status_file, 'w') as f:
                json.dump(status, f, indent=2)
    
    elif args.mode == 'test':
        processor = CargoTestParser(args.max_per_group)
        result = processor.parse(input_data)
        
        # Update status file if provided
        if args.status_file:
            try:
                with open(args.status_file, 'r') as f:
                    status = json.load(f)
            except FileNotFoundError:
                status = {}
            
            if 'test_phase' not in status:
                status['test_phase'] = {
                    'started_at': datetime.now(timezone.utc).isoformat(),
                    'iteration': 1
                }
            
            status['test_phase']['test_groups'] = result['test_groups']
            status['test_phase']['total_failures'] = result['failure_count']
            status['test_phase']['last_check'] = datetime.now(timezone.utc).isoformat()
            
            with open(args.status_file, 'w') as f:
                json.dump(status, f, indent=2)
    
    # Output result as JSON
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()