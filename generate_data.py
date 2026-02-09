import boto3
import csv
import random
import io
from datetime import datetime, timedelta
from faker import Faker

# Initialize Faker and Boto3
fake = Faker()
s3 = boto3.client('s3')

# Configuration
BUCKET_NAME = 'papas412-etl-raw-bucket'  # Must match your Terraform variable
FILE_NAME = f'weather_data_{int(datetime.now().timestamp())}.csv'

def generate_weather_row():
    # Generate timestamp
    dt = fake.date_time_between(start_date='-1d', end_date='now')
    ts_utc = dt.isoformat()
    ts_epoch = int(dt.timestamp())
    
    return [
        round(random.uniform(0, 1000), 2),  # ghi
        round(random.uniform(0, 500), 2),   # dhi
        round(random.uniform(0, 50), 2),    # precip
        ts_utc,                             # timestamp_utc
        round(random.uniform(-10, 40), 1),  # temp
        round(random.uniform(-10, 45), 1),  # app_temp
        round(random.uniform(0, 1000), 2),  # dni
        round(random.uniform(0, 100), 1),   # snow_depth
        random.choice(['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']), # wind_cdir
        round(random.uniform(0, 100), 0),   # rh
        random.choice(['d', 'n']),          # pod
        round(random.uniform(0, 100), 0),   # pop
        round(random.uniform(200, 400), 1), # ozone
        random.randint(0, 100),             # clouds_hi
        random.randint(0, 100),             # clouds
        round(random.uniform(0, 20), 1),    # vis
        round(random.uniform(0, 30), 1),    # wind_spd
        random.choice(['North', 'South', 'East', 'West']), # wind_cdir_full
        round(random.uniform(980, 1050), 1),# slp
        dt.strftime('%Y-%m-%d:%H'),         # datetime
        ts_epoch,                           # ts
        round(random.uniform(900, 1050), 1),# pres
        round(random.uniform(-10, 25), 1),  # dewpt
        round(random.uniform(0, 12), 1),    # uv
        random.randint(0, 100),             # clouds_mid
        random.randint(0, 360),             # wind_dir
        round(random.uniform(0, 50), 1),    # snow
        random.randint(0, 100),             # clouds_low
        round(random.uniform(0, 1000), 2),  # solar_rad
        round(random.uniform(0, 50), 1),    # wind_gust_spd
        ts_utc,                             # timestamp_local (simplified)
        fake.sentence(),                    # description
        str(random.randint(200, 800)),      # code
        "icon_to_drop"                      # icon (will be dropped by Lambda)
    ]

def generate_csv_and_upload():
    header = [
        "ghi", "dhi", "precip", "timestamp_utc", "temp", "app_temp", "dni", "snow_depth", 
        "wind_cdir", "rh", "pod", "pop", "ozone", "clouds_hi", "clouds", "vis", "wind_spd", 
        "wind_cdir_full", "slp", "datetime", "ts", "pres", "dewpt", "uv", "clouds_mid", 
        "wind_dir", "snow", "clouds_low", "solar_rad", "wind_gust_spd", "timestamp_local", 
        "description", "code", "icon"
    ]
    
    # Create CSV in memory
    csv_buffer = io.StringIO()
    writer = csv.writer(csv_buffer)
    writer.writerow(header)
    
    # Generate 50 rows
    for _ in range(50):
        writer.writerow(generate_weather_row())
        
    print(f"Generated {FILE_NAME} with 50 rows.")
    
    # Upload to S3
    try:
        s3.put_object(Bucket=BUCKET_NAME, Key=f"raw/{FILE_NAME}", Body=csv_buffer.getvalue())
        print(f"Successfully uploaded to s3://{BUCKET_NAME}/raw/{FILE_NAME}")
    except Exception as e:
        print(f"Error uploading to S3: {e}")

if __name__ == "__main__":
    generate_csv_and_upload()
