#PERFORMANCE POPULATOR V3

## INTRODUCTION
Performance Populator V3 enables us to populate and set up an environment which mimics the production environment wrt amount of data, for performance testing purposes. The populator generates the data based on a spec file, which specifies how much an item should be populated.
#####Use Cases
 * As a performance quality gate between production and development. 
 * Populated data can be used for performance testing
 * Populated data can be used for load/stress testing

#####Features
 * Upscaling/Downscaling: For Adding/Removing records to a model, just update the spec_config.yml and run the populator. Only extra required records will be populated/deleted.
 * Easy to introduce Populator for new model
 * Data Consistency: Unit tests of populator make sure populator is consistant with new migrations and validations.
 * Data Population: Integeration tests of populator make sure data is getting populated according to the specified spec.

## SPEC_CONFIG.YML
The populator decides how much to populate an item (or a model) based on the configuration parameters mentioned in `spec_config.yml` file. Each key in this file corresponds to a *node*. In each node, we commonly populate a model but it is not restricted to that. For instance, the node `:article` may populate the `Article` model whereas the node with key `:media_article` may populate articles with media type. The nodes are arranged in a hierarchial fashion and the actual counts are calculated as ratio to the parent. The first node (or root of the tree) that is processed is the organization and after that one by one all others are populated. Features and constants associated with organization node only.
```
node:
  parent: name of parent node with respect to current node
  percent: percent of parent model's count
  count: count of child model corresponding to the percent
  scope: organization/program (model is associated with program or organization)
  dependency: array of models which has to be populated before this model - optional
  additional_selects: array of filter methods on the parent model - optional
```
######For Example
```ruby
article:
  parent: member # parent key
  percent: [[25, 1000], 50] # The items in the array may be a number or another array with 2 elements, meaning explained below
  count: [2, 1] # 25% of members (or at max 1000 members) in that organization will have 2 articles, 50% will have 1 and rest none
  scope: organization
  dependency: [organization, program] # just example, not actual case
```
In additon to this, you can add any data parameter here which you can use later inside the node populator class (which is explained later in this doc). This can be used for specific cases or feature enabling or disabling etc. Please note that we can have either a number or a array with 2 elements in the `percents` key array. If there is a number, it simply say that much percent of the parent is supposed to have the corresponding child elements, but if it is a array with 2 numbers,  the 1st number demotes the same, ie, the percentage of the parent and the second number denotes the max cap limit. For example, if we have 2 organization types, say small and huge, which has 1000 and 100,000 members. And if we have percents key as [[50, 1000], ...], this will result in 500 members for small type org, since 50% of 1000 is not exceeding the cap limit of 1000, and the same instruction will result in 1000 members for huge type org and not 50,000 members, since it is limited to maximum of 1000 by the second value.

##POPULATOR MANAGER
Populator manager is core module which uses the spec file to build and determine the traverse order (the order in which each node to be visited). It also manages the dependencies between nodes. Additionally, this populator manager handles creation of organizatio and program.

##POPULATOR TASK
Populator tasks are modules which actually focusses on the indiviudal nodes and populate (add or remove) them. This needs to be updated when a new model is introduced or updated. Please see the example below for more info.

##TESTS
Two types of testing is done here, Unit tests are written to check if the model is populated correctly. Integration test runs the entire suite against a smaller config spec and matches populated database with values from spec directly to check for inconsistency with counts.
Adding a new key to the populator needs to have a corresponding test case in both unit test and integration test.

####UNIT TESTS
For each new model we have write and test 2 functionality:
* adding
* removing
This can be seen from any of the populator task test file.

####INTEGRATION TESTS
An end to end test to be run from local which runs a smaller spec, perf_spec_config.yml to check whether population of data happens as expected by comparing spec count to count from database. It runs four times. First time with given spec and populats data and validates if all models have been populated with given count. Second time it takes the same spec and run again to check if spec doesn't change each populated model count should not change. Third time it upscales count of few model and validates each model has been populated with modified count. Fourth time it downscales count of few model and validates each model has been populated with new count.

######PERF_POPULATOR_SPEC_CONFIG.YML
```
node:
  parent_key: Used to get child model count relative to parent model only for end to end test - optional
  model: Specify exact model file for use in integration test - Optional
  scope_column: Used to get count of model relative to organization or program in query only for end to end test - optional
```
######For Example
```ruby
article:
  parent_key: author
  model: Article 
  scope_column: author_id
```

##INTROUDUCING A NEW MODEL
**Step 1:** Update `spec_config.yml` with your model description - 
```ruby
node: # name of the node (or model)
  parent: parent_model_name # primary parent
  percent: [x, y, z]
  count: [a, b, c] # 'x'% of parent will have 'a' count of this node and so on
  scope: program # or organization
  dependency: [list_of_other_parents_or_dependencies] # optional
```
For instance, let's take `connection_answer`:
```
connection_answer:
  parent: group
  percent: [10, 90]
  count: [20, 1]
  scope: program
  dependency: [connection_question]
```
The `dependency` key, lists the keys to be populated before connection answer populator, here connection question populator has to be called. Scope tells this node is associated to program or organization.

**Step 2:** Write individual populator - go to `lib/populator_v3/performance_populator_tasks` and create file with name `node_populator.rb` with a corresponding class, ie, `NodePopulator` (because this is the default model the populator manager tries to load and call). Then we need to write three functions:
  * `patch` - This function generates count hash of child model with its parent and sends to populator task which comes up with how many child model has to be populated and deleted
  * `add_node` - populate child model with given count
  * `remove_node` - remove child model with given count

**Step 3:** Write unit tests - go to `/test/unit/lib/tasks/populator/performance_populator/performance_populator_tasks`
create file with name `node_populator_test.rb`. We need to write two function here:
  * add_model - test models is populated
  * remove_model - test models is removed

**Step 4:** Update end to end test
  * Update `perf_populator_spec_config.yml` with your model description like done on `spec_config.yml`
  * If the model population works as the common scenario, it is enough to add the model in common end to end test, else it should be added to `INDIVIDUAL_LIST` and seperate test should be written for it
  * Run the command `rake performance_populator:integration_test RAILS_ENV=test` to test end to end test

###NOTES
1. Use `bundle exec rake performance_populator:setup` to run populator.
 * If you want to run populator from scratch use `bundle exec rake db:drop db:create db:migrate` before running the populator rake task.
2. Create new database, and use `MY_DATABASE=<new database name> bundle exec rake performance_populator:integration_test` to run integration test
3. Unit tests will run along with other normal unit tests
4. Need to configure mysql if you get 'mysql has gone away' error
 * open /etc/mysql/my.cnf, set `wait_timeout = 600 seconds` and `max_allowed_packet = 64M`
 * restart mysql using `/etc/init.d/mysql restart`
5. Please write the populator in such a way that it mimizes the populate calls. For ex, prefer
```ruby
users = [] # array of users
index = 0
Rating.populate(users.size) do |rating|
  user = users[index]
  rating.user_id = user.id
  # set other values...
  index += 1
end
```
instead of 
```ruby
users.each do |user|
  Rating.populate(1) do |rating|
    rating.user_id = user.id
    # set other values...
    index += 1
  end
end
```

###ADDITIONAL MISC INFO REGARDING TESTS
* Count of parent model can be calculated relative to program/organization by query like `parent.camelize.constantize.where(scope_column.to_s => program.id/organization.id)`
* The model and its parent can be compared in most cases by the queries like `child_model.camelize.constantize.count(:all, :group => "#{parent_key}_id").group_by{|k, v|  v}.sort.map{|k,v| [k, v.size]}`. If so, calling `compare_counts` should suffice, else an individual test needs to be written and can be tested with `compare_counts_individual`.

### ADDITIONAL INFO ABOUT POPULATOR V3
* Changes(addition/deletion of attributes) in a model will be caught by Unit Tests
* Running Populator from scratch will be a time consuming process. But upscaling/downscaling or introducing populator for new models will be optimal. 
* Populator data will be reset once every quarter with updated config file, to make sure it is always similar(1.5 times) to production data.
* 2-3 hours is required to write populator for new model including unit/integration tests.
