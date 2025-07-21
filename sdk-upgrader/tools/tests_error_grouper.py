#!/usr/bin/env python3
"""
Parse cargo test output and group failures by module/crate.
This is used by the orchestrator to create focused work units for test-fixing agents.
"""

import json
import subprocess
import re
from collections import defaultdict
from datetime import datetime, timezone

def parse_test_output(test_output):
    """Parse cargo test output and extract test failures."""
    failures = []
    
    lines = test_output.strip().split('\n')
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Look for test failure patterns
        # Format: "test module::path::test_name ... FAILED"
        if re.match(r'^test\s+\S+.*\s+FAILED$', line):
            match = re.match(r'^test\s+(\S+)\s+.*\s+FAILED$', line)
            if match:
                test_path = match.group(1)
                
                # Extract module and test name
                parts = test_path.split('::')
                if len(parts) >= 2:
                    # First part is usually the crate/module
                    module = parts[0]
                    test_name = test_path
                    
                    failure_info = {
                        'test_path': test_path,
                        'module': module,
                        'test_name': test_name,
                        'line': i + 1,
                        'failure_output': []
                    }
                    
                    # Look for failure output after this line
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
    
    return failures

def group_failures_by_module(failures):
    """Group test failures by their module/crate."""
    groups = defaultdict(list)
    
    for failure in failures:
        module = failure['module']
        groups[module].append(failure)
    
    return dict(groups)

def create_test_groups(grouped_failures, max_tests_per_group=5):
    """Create test groups for the orchestrator."""
    test_groups = []
    group_id = 1
    
    # Sort by number of failures (descending) to prioritize modules with most failures
    sorted_modules = sorted(grouped_failures.items(), key=lambda x: len(x[1]), reverse=True)
    
    for module, failures in sorted_modules:
        # Split large failure sets into multiple groups
        for i in range(0, len(failures), max_tests_per_group):
            failure_batch = failures[i:i + max_tests_per_group]
            
            test_groups.append({
                'id': f'test_group_{group_id:03d}',
                'module': module,
                'test_count': len(failure_batch),
                'tests': [f['test_name'] for f in failure_batch],
                'status': 'pending',
                'failures': failure_batch
            })
            group_id += 1
    
    return test_groups

def run_cargo_test():
    """Run cargo test and return output."""
    cmd = ['cargo', 'test', '--workspace', '--no-fail-fast', '--', '--test-threads=1', '--nocapture']
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout + result.stderr

def save_test_groups(test_groups, status_file):
    """Save test groups to status file."""
    try:
        with open(status_file, 'r') as f:
            status = json.load(f)
    except FileNotFoundError:
        status = {
            'strategy': 'error_based_sequential',
            'created_at': datetime.now(timezone.utc).isoformat()
        }
    
    # Initialize or update test_phase
    if 'test_phase' not in status:
        status['test_phase'] = {
            'started_at': datetime.now(timezone.utc).isoformat(),
            'iteration': 1
        }
    
    status['test_phase']['test_groups'] = test_groups
    status['test_phase']['total_failures'] = sum(g['test_count'] for g in test_groups)
    status['test_phase']['last_check'] = datetime.now(timezone.utc).isoformat()
    
    with open(status_file, 'w') as f:
        json.dump(status, f, indent=2)
    
    return status

def update_status_file(status_file, test_groups):
    """Update existing status file with new test groups."""
    return save_test_groups(test_groups, status_file)

def main():
    """Main function with command-line interface."""
    import sys
    import argparse
    
    parser = argparse.ArgumentParser(description='Parse and group cargo test failures')
    parser.add_argument('command', choices=['parse', 'group', 'test'], 
                        help='Command to run')
    parser.add_argument('--max-per-group', type=int, default=5,
                        help='Maximum tests per group (default: 5)')
    parser.add_argument('--status-file', default='status.json',
                        help='Status file path (default: status.json)')
    parser.add_argument('--input', '-i', help='Input file (default: stdin)')
    
    args = parser.parse_args()
    
    if args.command == 'parse':
        # Read test output from stdin or file
        if args.input:
            with open(args.input, 'r') as f:
                test_output = f.read()
        else:
            test_output = sys.stdin.read()
        
        failures = parse_test_output(test_output)
        print(json.dumps({
            'failure_count': len(failures),
            'failures': failures
        }, indent=2))
    
    elif args.command == 'group':
        # Read parsed failures from stdin
        parsed_data = json.loads(sys.stdin.read())
        failures = parsed_data.get('failures', [])
        
        if not failures:
            print(json.dumps({
                'failure_count': 0,
                'groups': []
            }, indent=2))
            return
        
        grouped = group_failures_by_module(failures)
        test_groups = create_test_groups(grouped, args.max_per_group)
        
        # Update status file
        update_status_file(args.status_file, test_groups)
        
        print(json.dumps({
            'failure_count': len(failures),
            'group_count': len(test_groups),
            'groups': test_groups
        }, indent=2))
    
    elif args.command == 'test':
        # Original test functionality
        print("Running cargo test...")
        test_output = run_cargo_test()
        
        print("Parsing test failures...")
        failures = parse_test_output(test_output)
        print(f"Found {len(failures)} test failures")
        
        if not failures:
            print("All tests passed!")
            return
        
        print("\nGrouping failures by module...")
        grouped = group_failures_by_module(failures)
        print(f"Created {len(grouped)} module groups")
        
        # Show top modules with failures
        print("\nTop modules with test failures:")
        for module, fails in sorted(grouped.items(), key=lambda x: len(x[1]), reverse=True)[:10]:
            print(f"  {module}: {len(fails)} failures")
        
        print("\nCreating test groups...")
        test_groups = create_test_groups(grouped, args.max_per_group)
        print(f"Created {len(test_groups)} test groups")
        
        # Save to status file
        update_status_file(args.status_file, test_groups)
        print(f"\nSaved to {args.status_file}")

if __name__ == "__main__":
    main()