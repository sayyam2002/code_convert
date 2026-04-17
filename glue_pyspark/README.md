# AWS Glue PySpark Job - Customer Order Analytics with SCD Type 2

## Project Overview
This AWS Glue PySpark job implements a complete ETL pipeline for customer order analytics with Slowly Changing Dimension (SCD) Type 2 tracking using Apache Hudi.

## Functional Requirements (FRD)
- **FR-INGEST-001**: Ingest customer data from S3 CSV files
- **FR-INGEST-002**: Ingest order data from S3 CSV files
- **FR-CLEAN-001**: Remove NULL and 'Null' string values
- **FR-CLEAN-002**: Remove duplicate records
- **FR-SCD2-001**: Implement SCD Type 2 with Hudi for customer dimension
- **FR-AGG-001**: Calculate customer aggregate spend
- **FR-CATALOG-001**: Register tables in AWS Glue Catalog

## Technical Requirements (TRD)

### Data Sources
- **Customer Data**: `s3://adif-sdlc/sdlc_wizard/customerdata/`
  - Schema: CustId (String), Name (String), EmailId (String), Region (String)
  - Format: CSV with UTF-8 encoding

- **Order Data**: `s3://adif-sdlc/sdlc_wizard/orderdata/`
  - Schema: OrderId (String), ItemName (String), PricePerUnit (Double), Qty (Integer), Date (String)
  - Format: CSV with UTF-8 encoding

### Output Paths
- **Order Summary**: `s3://adif-sdlc/curated/sdlc_wizard/ordersummary/`
- **Customer Aggregate Spend**: `s3://adif-sdlc/analytics/customeraggregatespend/`

### SCD Type 2 Configuration
- **Format**: Apache Hudi
- **Columns**: IsActive (Boolean), StartDate (Timestamp), EndDate (Timestamp), OpTs (Timestamp)
- **Operation**: Upsert
- **Record Key**: CustId

## Project Structure
```
glue_pyspark/
├── .gitignore
├── README.md
├── requirements.txt
├── pytest.ini
├── config/
│   └── glue_params.yaml
└── src/
    ├── __init__.py
    ├── main/
    │   ├── __init__.py
    │   └── job.py
    └── test/
        ├── __init__.py
        └── test_job.py
```

## Setup Instructions

### Prerequisites
- Python 3.7+
- AWS CLI configured
- IAM role with S3 and Glue permissions

### Installation
```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Running Tests
```bash
# Run all tests
pytest src/test/ -v

# Run with coverage
pytest src/test/ --cov=src/main --cov-report=html

# Run specific test
pytest src/test/test_job.py::test_read_customer_data -v
```

## AWS Glue Job Configuration

### Job Parameters
```yaml
--JOB_NAME: customer_order_analytics_scd2
--CUSTOMER_INPUT_PATH: s3://adif-sdlc/sdlc_wizard/customerdata/
--ORDER_INPUT_PATH: s3://adif-sdlc/sdlc_wizard/orderdata/
--ORDER_SUMMARY_OUTPUT_PATH: s3://adif-sdlc/curated/sdlc_wizard/ordersummary/
--CUSTOMER_AGG_OUTPUT_PATH: s3://adif-sdlc/analytics/customeraggregatespend/
--GLUE_DATABASE: sdlc_wizard_db
--ENABLE_SPARK_UI: true
--spark.serializer: org.apache.spark.serializer.KryoSerializer
```

### IAM Permissions Required
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::adif-sdlc/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "glue:GetDatabase",
        "glue:GetTable",
        "glue:CreateTable",
        "glue:UpdateTable"
      ],
      "Resource": "*"
    }
  ]
}
```

## Data Flow

1. **Ingestion**: Read customer and order data from S3
2. **Validation**: Validate S3 paths and data availability
3. **Cleaning**: Remove NULL values, 'Null' strings, and duplicates
4. **Transformation**: Normalize column names to lowercase
5. **SCD Type 2**: Apply Hudi upsert with historical tracking
6. **Aggregation**: Calculate customer aggregate spend
7. **Catalog**: Register tables in AWS Glue Catalog
8. **Output**: Write results to S3 in Parquet/Hudi format

## Monitoring
- CloudWatch Logs: `/aws-glue/jobs/output`
- Spark UI: Enabled via job parameters
- Job Metrics: Available in AWS Glue Console

## Troubleshooting

### Common Issues
1. **S3 Access Denied**: Verify IAM role permissions
2. **Schema Mismatch**: Check CSV file headers match expected schema
3. **Hudi Write Failure**: Ensure sufficient memory allocation
4. **Glue Catalog Error**: Verify database exists and permissions

## Contact
For issues or questions, contact the data engineering team.