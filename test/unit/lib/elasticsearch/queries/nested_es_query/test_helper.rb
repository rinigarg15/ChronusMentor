module NestedEsQuery
  module TestHelper
    def assert_filtered_ids(query, expected)
      query_executor(query) do
        assert_equal_unordered expected, query.get_filtered_ids
      end
    end

    def assert_id_in_filtered_ids(query, expected)
      query_executor(query) do
        assert expected.in?(query.get_filtered_ids)
      end
    end

    def assert_id_not_in_filtered_ids(query, expected)
      query_executor(query) do
        assert_false expected.in?(query.get_filtered_ids)
      end
    end

    def query_executor(query)
      initial_filterable_ids = query.filterable_ids
      yield
      query.filterable_ids = initial_filterable_ids
    end
  end
end