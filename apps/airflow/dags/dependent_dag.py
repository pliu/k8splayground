from airflow import DAG
from datetime import datetime, timedelta
from airflow.operators.bash_operator import BashOperator
from airflow.sensors.external_task_sensor import ExternalTaskSensor


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2020, 6, 7),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1)
}

dag = DAG(
    'dependent-dag',
    default_args=default_args,
    schedule_interval='*/5 * * * *',
    catchup=False,
)

start = ExternalTaskSensor(
    task_id='start-task',
    external_dag_id='example-dag',
    external_task_id='python-print',
    execution_delta=timedelta(minutes=5),
    timeout=3*60,
    dag=dag,
)

curl = BashOperator(
    bash_command=r"""curl -H "Content-Type: application/json" -d '{"status":"dependency successful", "time":"{{ ts }}"}' mock-server.default.svc.cluster.local""",
    task_id="curl-task",
    dag=dag,
)

curl.set_upstream(start)
