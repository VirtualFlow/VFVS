#!/usr/bin/env python3

# Copyright (C) 2019 Christoph Gorgulla
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# This file is part of VirtualFlow.
#
# VirtualFlow is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# VirtualFlow is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with VirtualFlow.  If not, see <https://www.gnu.org/licenses/>.

# ---------------------------------------------------------------------------

import boto3
from botocore.config import Config
import time
import argparse
import json


def parse_config(filename):
  with open(filename, "r") as read_file:
      config = json.load(read_file)

  return config

def wait_for_athena_completion(athena_client, s3_client, response_to_wait, delete=1, desc="unknown"):

  finished_states = ['SUCCEEDED', 'FAILED', 'CANCELLED']

  print(f"Waiting on {desc} ({response_to_wait['QueryExecutionId']})")
  while True:

    response = athena_client.get_query_execution(
        QueryExecutionId=response_to_wait['QueryExecutionId']
    )

    time.sleep(0.5)

    if(response['QueryExecution']['Status']['State'] in finished_states):

      if(delete == 1 and response['QueryExecution']['Status']['State'] == "SUCCEEDED"):
        # remove the old data
        obj_parts = response['QueryExecution']['ResultConfiguration']['OutputLocation'].split("/")
        obj_combined = "/".join(obj_parts[3:])

        del_response = s3_client.delete_object(
          Bucket=obj_parts[2],
          Key=obj_combined
        )

      break

  return response



def main():

  ctx = {}
  ctx['config'] = parse_config("../workflow/config.json")

  # Verify that there is a parquet output
  if 'parquet' not in ctx['config']['summary_formats']:
    print("In order to use the query, `parquet` must be a summary_format")
    exit(1)

  if ctx['config']['batchsystem'] != 'awsbatch':
    print("In order to use this query script, AWS must be configured")
    exit(1)

  scenario_required = True
  scenario_default = None

  parser = argparse.ArgumentParser()

  if(len(ctx['config']['docking_scenarios_internal']) == 1):
    scenario_required = False
    scenario_default = list(ctx['config']['docking_scenarios_internal'].keys())[0]
    parser.add_argument('--scenario-name', action='store', type=str, required=scenario_required, default=scenario_default)
  else:
    parser.add_argument('--scenario-name', action='store', type=str, required=True)



  parser.add_argument('--top', action='store', type=int, required=False)
  args = parser.parse_args()

  botoconfig = Config(
  	region_name = ctx['config']['aws_region'],
  	retries = {
  		'max_attempts': 50,
  		'mode': 'standard'
  	}
  )

  args_dict = vars(args)

  scenario = args_dict['scenario_name']

  if scenario not in ctx['config']['docking_scenarios_internal']:
    print(f"Scenario '{scenario}'' is not defined as part of this job")
    exit(1)

  table_name = f"{ctx['config']['job_name']}__{scenario}".replace("-","_")

  athena_location = ctx['config']['athena_s3_location']
  database_name = f"{ctx['config']['aws_batch_prefix']}_vfvs"
  job_location = f"{ctx['config']['object_store_job_prefix_full']}/{scenario}/parquet"
  object_store_job_bucket = ctx['config']['object_store_job_bucket']
  scenario_info = ctx['config']['docking_scenarios_internal'][scenario]


  client = boto3.client('athena', config=botoconfig)
  s3_client = boto3.client('s3', config=botoconfig)

  print("Running query in AWS Athena\n")


  # Create database

  create_database = f"""
  CREATE DATABASE IF NOT EXISTS {database_name}
    COMMENT 'VFVS output for Athena'
    LOCATION '{athena_location}';
  """
  athena_location_tmp = f"{athena_location}/tmp"

  create_db_response = client.start_query_execution(
      QueryString=create_database,
      QueryExecutionContext={
          'Catalog': 'AwsDataCatalog'
      },
      ResultConfiguration={
          'OutputLocation': athena_location_tmp
      }
  )

  response = wait_for_athena_completion(client, s3_client, create_db_response, desc="createdb if needed")
  if(response['QueryExecution']['Status']['State'] != "SUCCEEDED"):
    print(f"failed on createdb ({response['QueryExecution']['Status']['State']})")
    exit(1)

  drop_response = client.start_query_execution(
      QueryString=f"DROP TABLE IF EXISTS {table_name};",
      QueryExecutionContext={
          'Database': database_name,
          'Catalog': 'AwsDataCatalog'
      },
      ResultConfiguration={
          'OutputLocation': f'{athena_location}/tmp'
      }
  )

  response = wait_for_athena_completion(client, s3_client, drop_response, desc="dropping of old table")
  if(response['QueryExecution']['Status']['State'] != "SUCCEEDED"):
    print(f"failed on drop of old table ({response['QueryExecution']['Status']['State']})")
    exit(1)

  # Generate the table based on the configuration

  field_type = {
    'ligand': "STRING",
    'collection_key': "STRING",
    'scenario': "STRING",
    'score_average': "DOUBLE",
    'score_min': "DOUBLE"
  }

  fields = [ 'ligand', 'collection_key', 'scenario' ]
  for replica_index in range(int(scenario_info['replicas'])):
    fields.append(f"score_{replica_index}")
    field_type[f"score_{replica_index}"] = "DOUBLE"

  fields.append("score_average")
  fields.append("score_min")

  for attr in ctx['config']['print_attrs_in_summary']:
    fields.append(f"attr_{attr}")
    field_type[f"attr_{attr}"] = "STRING"


  generate = []
  for field_name in fields:
    generate.append(f"{field_name} {field_type[field_name]}")

  create_table_list = ",\n".join(generate)

  create_table = f"""
  CREATE EXTERNAL TABLE {table_name} (
      {create_table_list}
  )
  STORED AS PARQUET
  LOCATION 's3://{object_store_job_bucket}/{job_location}'
  tblproperties ("parquet.compression"="GZIP");
  """

  create_table_response = client.start_query_execution(
      QueryString=create_table,
      QueryExecutionContext={
          'Database': database_name,
          'Catalog': 'AwsDataCatalog'
      },
      ResultConfiguration={
          'OutputLocation': f'{athena_location}/tmp'
      }
  )

  response = wait_for_athena_completion(client, s3_client, create_table_response, desc="create table")
  if(response['QueryExecution']['Status']['State'] != "SUCCEEDED"):
    print(f"failed on create of table ({response['QueryExecution']['Status']['State']})")
    exit(1)


  if 'top' in args_dict and args_dict['top'] != None:
    top_string = f"limit {args_dict['top']}"
  else:
    top_string = ""

  select_statement = f"SELECT * from {table_name} ORDER BY score_min ASC {top_string};"

  select_response = client.start_query_execution(
      QueryString=select_statement,
      QueryExecutionContext={
          'Database': database_name,
          'Catalog': 'AwsDataCatalog'
      },
      ResultConfiguration={
          'OutputLocation': f'{athena_location}',
      }
  )

  response = wait_for_athena_completion(client, s3_client, select_response, delete=0, desc="query")

  print("")
  print(f"STATUS: {response['QueryExecution']['Status']['State']}")
  print(f"Output location: {response['QueryExecution']['ResultConfiguration']['OutputLocation']}")

if __name__ == '__main__':
    main()



