"""
Main package for AWS Glue PySpark job implementation
Contains core ETL logic and transformations
"""

from .job import (
    initialize_spark_contexts,
    read_data_safe,
    write_data_safe,
    validate_s3_path,
    clean_data,
    apply_scd_type2,
    calculate_customer_aggregate_spend,
    main
)

__all__ = [
    "initialize_spark_contexts",
    "read_data_safe",
    "write_data_safe",
    "validate_s3_path",
    "clean_data",
    "apply_scd_type2",
    "calculate_customer_aggregate_spend",
    "main"
]