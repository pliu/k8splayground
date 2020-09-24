# Airflow
Airflow is a popular workflow scheduler that schedules and distributes work using an executor framework. The Airflow scheduler consists of a server, a scheduler, and a database (in K8sPlayground, PostgreSQL is used) for storing the state of DAGs, their runs, and tasks. The executor framework used by Airflow in K8sPlayground is Celery, using Redis as the underlying message broker.

Workflows are defined as DAGs - user-specified Python programs that define a set of tasks and dependencies between them that is run by Airflow and scheduled to satisfy the dependencies specified. Each DAG also specifies a run schedule (e.g., every 5 minutes, every month, once). It is important to note that a single DAG can have multiple, overlapping runs (e.g. if DAG A runs every 5 minutes but takes 10 minutes to complete, then you'd expect a period where two runs overlap). Airflow has a number of options for determining how to handle these potentially overlapping runs (e.g., allowing them to run concurrently, serializing them with and without backlog). Example DAGs can be found in the dags/ folder.

To load these DAGs into Airflow, the scheduler, server, and workers all have a git-sync container alongside them that updates DAGs every minute by pulling from the configured Git repository containing the DAGs (the branch used can also be specified). Thus, for Airflow to pick up any DAG changes, they must first be pushed to the Git repository. Additionally, by default, Airflow only considers .py files containing either 'airflow' or 'dag' in the name.

After the DAGs are loaded, each iteration of the scheduling loop checks active DAGs (DAGs are inactive by default and must be enabled from the Airflow UI before running) to determine whether it is time to create a run of the DAG, and if so, creates the tasks defined by the DAG and writes them to the database, along with whether they are ready to be scheduled (i.e. have all of their dependencies been met). It also loops over existing tasks and checks if they are now ready to be scheduled.

The executor framework consists of a part that lives alongside the scheduler (hereafter, we refer to it as the executor), the message broker, and workers. The executor places tasks that are to be scheduled into the message broker. These tasks can be thought of as forming a queue that the workers consume from, executing the tasks that they've bitten off. The workers will subsequently update the the database with the status of the task (e.g., success, failed, up_for_retry). It is important to note that workers have a concurrency setting - the maximum number of tasks a given worker will run at a time - and that the queue can become clogged (or deadlocked) if too many of these slots are occupied by tasks that are just waiting.

A diagram of the task lifecycle can be found [here](https://airflow.apache.org/docs/stable/_images/task_lifecycle_diagram.png).

The Airflow server serves the Airflow UI - pulling the status of DAGs, their runs, and tasks, task logs, and other configurations from the database and displaying them for users. When users request task logs, the server requests the logs from the worker that ran the task (you can see these requests in the worker's logs using `kubectl logs`). Users can also manually control DAGs and tasks from the UI (e.g., manually triggering DAG runs, setting/unsetting the status of tasks).

In addition to the Airflow server, the chart also deploys Flower, a UI for exploring the Celery executor framework. With Flower, you can inspect the registered workers as well as the tasks in the message broker. It should be noted that the status of tasks displayed in Flower is from Celery's perspective as an executor framework (i.e. did a worker successfully execute the task) and not from the perspective of Airflow (i.e. did the task execute successfully and return a zero exit code).

Finally, two important, yet confusing, areas to pay attention to when creating or modifying DAGs are expression evaluation and changing the IDs of running DAGs. For expression evaluation, it is important to know when the expression is evaluated. An example of when this is important is obtaining the current time and date for use as the start time of a DAG or for use within tasks. When changing the IDs of running DAGs, it is important to understand how this will affect current and historical runs of the previous version of the DAG and the backfilling behaviour of the new version of the DAG.

Examples of things to experiment with:

- using readiness and liveness probe on Pods to validate a healthy startup and continued health, respectively, and their effect on service routing
- using persistent volumes to persist data between Pod lifetimes
- navigating the Airflow UI (e.g., viewing and interacting with DAGs and their tasks, finding logs for debugging)
- determining when expressions are evaluated (e.g. DAG load time, DAG run time, task execution time)
- understanding the effect of changing the IDs of running DAGs
- trying different operators
- testing various DAG and task scheduling options (e.g., backfilling, concurrency, parallelism)
- constructing more advanced DAGs with conditional tasks (e.g., triggers, branching)
- creating DAGs with inter-DAG dependencies (e.g., sub-DAGs, ExternalTaskSensor)
- using pools and queues to isolate load and direct work to specific workers
- coming up with a solution to export user-generated code onto the appropriate workers to be called by tasks
- creating custom operators
- coming up with a solution to manage secrets for use within tasks (e.g., Airflow connections, external secret management)
- setting up authentication and authorization
- changing executor frameworks (e.g. Kubernetes executors)
- exploring the internal representation of tasks in PostgreSQL and Redis
- understanding how Celery distributes and retries, if necessary, tasks to workers

## Testing
If nginx-ingress is running, Airflow configuration changes and DAG changes can be verified from the Airflow UI on one's local machine. The Flower UI can be used to verify worker configuration changes and to track tasks in the Celery queue.
```
http://localhost/airflow
http://localhost/airflow/flower
```
Additionally, the current and historical statuses of DAG runs and tasks can be checked in the Airflow UI. A particularly useful feature of the UI is the graphical representation of DAGs, allowing you to easily visualize task dependencies.

When debugging DAGs, there are a couple of places that may contain useful logs. If the DAG definition has errors or there are errors scheduling or running tasks, looking at the Airflow server, scheduler, or worker logs using `kubectl logs` is a good place to start. If the code that the task runs has errors, then you should first check the task logs in the Airflow UI.

## Commands
```
Apply/update Airflow:
make airflow_apply

Delete Airflow:
make airflow_delete
```
