#!/usr/bin/env python3
"""
Split master phone list into batches
Usage: python3 split_phones.py
"""

MASTER_FILE = "data/masterPhone..txt"
BATCH_SIZE = 250
NUM_BATCHES = 14

def split_phones():
    # Read all phone numbers
    with open(MASTER_FILE, 'r') as f:
        phones = [line.strip() for line in f if line.strip()]
    
    total_phones = len(phones)
    print(f"Total phones: {total_phones}")
    
    # Split into batches
    for batch_num in range(1, NUM_BATCHES + 1):
        start_idx = (batch_num - 1) * BATCH_SIZE
        end_idx = min(start_idx + BATCH_SIZE, total_phones)
        
        batch_phones = phones[start_idx:end_idx]
        batch_file = f"data/phone_batch_{batch_num:02d}.txt"
        
        with open(batch_file, 'w') as f:
            f.write('\n'.join(batch_phones) + '\n')
        
        print(f"Created {batch_file}: {len(batch_phones)} phones")
    
    print(f"\n✅ Created {NUM_BATCHES} batches successfully!")

if __name__ == "__main__":
    split_phones()
