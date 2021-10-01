# Delayed Job Split Feature

Class [**"DjSplit"**](https://github.com/ChronusCorp/ChronusMentor/blob/develop/lib/dj_split.rb) is designed to **Split Time Taking Delayed Jobs, Crons, Bulk Operations, etc** into **smaller size multiple Delayed Jobs**.
These **Jobs** should be **mutually exclusive** of each other and should be able to run **concurrently**.

These **Jobs** can be picked by **Delayed Job Worker** across **Multiple Servers**. 

Class behaves like **Delayed Job Worker**, it also **picks and processes delayed job** entries.

**Splitting** will be done on **one parameter** only.

## Purpose:

To distribute the load among **multiple application servers**.

## Usage:

      $ match_client.bulk_mentor_match(student_ids, mentor_ids)

  can be replace by:

      $ DjSplit.new(queue_options: {queue: queue_name}, split_options: {size: 1000, by: 2}).enqueue(match_client, "bulk_mentor_match", student_ids, mentor_ids)

  used in [Matching Indexing](https://github.com/ChronusCorp/ChronusMentor/blob/develop/lib/matching/lib/cache/refresh.rb)


## Note: 

* Arguments must be in exact order.
* "enqueue" parameters are (object/class, function_name, arguments of that function)
* split_options[:size] is splitting size
* split_options[:by] is position of splitting attribute in the enqueue function. In above example, splitting attribute is student_ids and has position 2(>=2).
* split_options[:with] is position of the attribute where we pass the index of the chunk.

* Here we are splitting on the basis of student_ids. 
* We can also specify the: splitting_size, Otherwise it will take default Optimal Splitting Size
* After splitting and enqueuing, instead of waiting for the sub-jobs to be complete this function will behave like delayed job worker and will pick and process the sub-jobs instead of blocking.

## What DjSplit::Enqueue does:

* Split the mentioned parameter into array of chunks(arrays) of size = split_options[:size]. 
* Loop through the array and insert each chunk into Delayed Job queue(array element is placed in place of splitting params)
* Queue jobs will be picked and executed by workers
* Instead of waiting for jobs to be picked and processed by workers this function will also pick and process those job


## Heads up:

While splitting into delayed jobs, we should be aware that the jobs will be executed by workers in different server. Please double check if you have handled the following cases.

* Temporary files across servers.
* Logs across servers.
* Executing without delivering mails. It would have been switched off in the main server but not in the Delayed Job Workers.
* Setting Class level variables like I18n.locale
* Skipping indexes like in case of skip_es_delta_indexing
* If the splitting process happens within a block, make sure all the variables set before the splitting are handled in DJs.
* Use BlockExecutor.execute_without_mails to skip mails.
* Use CloudLogs to manage logs in CloudWatchLogs. It can be used to handle temporary files across servers.


