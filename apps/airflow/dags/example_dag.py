from airflow import DAG
from datetime import datetime, timedelta
from airflow.operators.bash_operator import BashOperator
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.python_operator import BranchPythonOperator
from airflow.operators.python_operator import PythonOperator
import random
import sys


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2020, 6, 7),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1)
}

def return_branch():
    return random.choice(['python-print', 'python-fail'])

def print_context(**kwargs):
    print(kwargs)
    return 'Whatever you return gets printed in the logs'

def exit_failure():
    sys.exit(1)

dag = DAG(
    'example-dag',
    default_args=default_args,
    schedule_interval='*/5 * * * *',
    catchup=False,
)

start = DummyOperator(
    task_id='start-task',
    dag=dag,
)

curl = BashOperator(
    bash_command=r"""curl -H "Content-Type: application/json" -d '{"status":"passing", "time":"{{ ts }}"}' mock-server.default.svc.cluster.local""",
    task_id="curl-task",
    dag=dag,
)

branch = BranchPythonOperator(
    task_id='branch',
    python_callable=return_branch,
    dag=dag,
)

python_print = PythonOperator(
    task_id='python-print',
    provide_context=True,
    python_callable=print_context,
    dag=dag,
)

python_fail = PythonOperator(
    task_id='python-fail',
    python_callable=exit_failure,
    dag=dag,
)

curl.set_upstream(start)
branch.set_upstream(start)
python_print.set_upstream(branch)
python_fail.set_upstream(branch)
