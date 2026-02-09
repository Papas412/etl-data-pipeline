import boto3
import csv
import io
import os
import json

s3 = boto3.client('s3')

def lambda_handler(event, context):
    
    # Get the bucket name from the event
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']

    # Get the object from the bucket
    response = s3.get_object(Bucket=bucket_name, Key=object_key)
    object_data = response['Body'].read()
    
    # Initialize Firehose client
    firehose = boto3.client('firehose')
    firehose_stream_name = os.environ.get('FIREHOSE_STREAM')

    try:
        # Process the object data
        processed_data = []
        firehose_records = []
        
        input_file = io.StringIO(object_data.decode('utf-8'))
        reader = csv.reader(input_file)
        
        # Read the header
        try:
            header = next(reader)
        except StopIteration:
            print("Empty file")
            return

        # Columns to drop
        COLUMNS_TO_DROP = ['icon']
        
        # Find indices of columns to keep
        keep_indices = [i for i, col in enumerate(header) if col not in COLUMNS_TO_DROP]
        new_header = [header[i] for i in keep_indices]
        
        processed_data.append(new_header)
        
        for row in reader:
            # Handle cases where row might be shorter than header
            if len(row) == len(header):
                new_row = [row[i] for i in keep_indices]
                processed_data.append(new_row)
                
                # Prepare for Firehose (create dict from header and row)
                if firehose_stream_name:
                    record_dict = dict(zip(new_header, new_row))
                    # Ensure JSON format with newline
                    payload = json.dumps(record_dict) + '\n' 
                    firehose_records.append({'Data': payload})
                    
            else:
                 # If row length doesn't match header (malformed CSV), try to keep valid indices
                 new_row = [row[i] for i in keep_indices if i < len(row)]
                 processed_data.append(new_row)

        # Write processed data to a temporary file
        temp_file_path = '/tmp/processed_data.csv'
        with open(temp_file_path, 'w', newline='') as temp_file:
            writer = csv.writer(temp_file)
            writer.writerows(processed_data)

        # Write the processed data to the final bucket
        processed_bucket_name = os.environ.get('PROCESSED_BUCKET')
        
        # Create processed key with _processed suffix
        key_without_prefix = object_key.replace('raw/', 'processed/')
        path_parts = os.path.splitext(key_without_prefix)
        processed_file_key = f"{path_parts[0]}_processed{path_parts[1]}"
        
        s3.put_object(Bucket=processed_bucket_name, Key=processed_file_key, Body=open(temp_file_path, 'rb'))
        os.remove(temp_file_path)

        print(f"Processed data written to {processed_file_key}")
        
        # Send to Firehose
        if firehose_stream_name and firehose_records:
            # Firehose PutRecordBatch has a limit of 500 records or 4MB
            chunk_size = 500
            for i in range(0, len(firehose_records), chunk_size):
                chunk = firehose_records[i:i + chunk_size]
                response = firehose.put_record_batch(
                    DeliveryStreamName=firehose_stream_name,
                    Records=chunk
                )
                failed = response.get('FailedPutCount', 0)
                if failed > 0:
                    print(f"Warning: {failed} records failed to be sent to Firehose in this batch")
            print(f"Sent {len(firehose_records)} records to Firehose stream {firehose_stream_name}")
            
    except Exception as e:
        print(f"Error processing object: {e}")
        raise e