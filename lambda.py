import boto3
import csv
import io
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    
    # Get the bucket name from the event
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']

    # Get the object from the bucket
    response = s3.get_object(Bucket=bucket_name, Key=object_key)
    object_data = response['Body'].read()

    try:
        # Process the object data
        processed_data = []
        reader = csv.reader(io.StringIO(object_data.decode('utf-8')))
        for row in reader:
            processed_data.append(row)

        # Write processed data to a temporary file
        temp_file_path = '/tmp/processed_data.csv'
        with open(temp_file_path, 'w') as temp_file:
            writer = csv.writer(temp_file)
            writer.writerows(processed_data)

        # Write the processed data to the final bucket
        processed_bucket_name = "papas412-etl-processed-bucket"
        processed_file_key = object_key.replace('raw/', 'processed/')
        s3.put_object(Bucket=processed_bucket_name, Key=processed_file_key, Body=open(temp_file_path, 'rb'))
        os.remove(temp_file_path)

        print(f"Processed data written to {processed_file_key}")

    except Exception as e:
        print(f"Error processing object: {e}")
        raise e