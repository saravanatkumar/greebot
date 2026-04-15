#!/usr/bin/env python3
"""
Split master phone list into batches
Usage: python3 split_phones.py
"""

MASTER_FILE = "data/masterPhone..txt"
BATCH_SIZE = 330
NUM_BATCHES = 14

def split_phones():
    # Read all phone numbers
    with open(MASTER_FILE, 'r') as f:
        phones = [line.strip() for line in f if line.strip()]
    
    total_phones = len(phones)
    print(f"Total phones: {total_phones}")
    
    # Calculate actual number of batches needed
    import math
    actual_batches = math.ceil(total_phones / BATCH_SIZE)
    print(f"Creating {actual_batches} batch(es) with {BATCH_SIZE} phones each\n")
    
    # Split into batches (only create non-empty batches)
    batches_created = 0
    for batch_num in range(1, actual_batches + 1):
        start_idx = (batch_num - 1) * BATCH_SIZE
        end_idx = min(start_idx + BATCH_SIZE, total_phones)
        
        batch_phones = phones[start_idx:end_idx]
        
        # Only create batch file if there are phones
        if batch_phones:
            batch_file = f"data/phone_batch_{batch_num}.txt"
            
            with open(batch_file, 'w') as f:
                f.write('\n'.join(batch_phones) + '\n')
            
            print(f"Created {batch_file}: {len(batch_phones)} phones")
            batches_created += 1
    
    print(f"\n✅ Created {batches_created} batch file(s) successfully!")

if __name__ == "__main__":
    split_phones()
