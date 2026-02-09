import boto3
import json
import random
import time
from faker import Faker

# Initialize Faker and Boto3
fake = Faker()
firehose = boto3.client('firehose', region_name='us-east-1')

STREAM_NAME = 'my-ecommerce-stream' # Must match your Terraform resource name

def generate_event():
    event_types = ['view_item', 'add_to_cart', 'purchase', 'remove_from_cart']
    return {
        'user_id': fake.uuid4(),
        'event_type': random.choice(event_types),
        'product_id': f"PROD-{random.randint(100, 999)}",
        'price': round(random.uniform(10.0, 500.0), 2),
        'timestamp': fake.date_time_between(start_date='-1h', end_date='now').isoformat(),
        'ip_address': fake.ipv4()
    }

def run_generator():
    print(f"Starting stream to {STREAM_NAME}...")
    while True:
        data = generate_event()
        # Firehose expects a newline between records for easier downstream parsing
        payload = json.dumps(data) + '\n'
        
        try:
            firehose.put_record(
                DeliveryStreamName=STREAM_NAME,
                Record={'Data': payload}
            )
            print(f"Sent: {data['event_type']} for {data['product_id']}")
        except Exception as e:
            print(f"Error: {e}")
            
        # Sleep to simulate real user pacing (e.g., 0.5 to 2 seconds)
        time.sleep(random.uniform(0.5, 2.0))

if __name__ == "__main__":
    run_generator()