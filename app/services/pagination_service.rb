class PaginationService
  
  def self.build_sort_options(model_name, field=nil, order=nil)
    sort_options = self.pagination_sort_options[model_name][[field, order]] || self.pagination_sort_options[model_name][self.pagination_sort_options[model_name]['default']]
    sort_options.slice(:field, :order, :order_string) 
  end

  def self.build_sort_fields(model_name)
    self.pagination_sort_options[model_name].except('default').values.collect{|field| field.slice(:field, :order, :label)}
  end

  def self.pagination_options(model_name='ActiveRecord::Base', page = 1)
    {
      :page => page,
      :per_page => model_name.constantize.per_page # 10 per_page by default
    }
  end

  private

  def self.pagination_sort_options
    options = {
      QaAnswer.name => {
          ["id" , "desc"]         => {:field => :id, :order => :desc, :order_string => "id DESC", :label => "feature.question_answers.header.sort_by.latest".translate},
          ["score" , "desc"]   => {:field => :score, :order => :desc, :order_string => "score DESC, id DESC", :label => "feature.question_answers.header.sort_by.most_helpful".translate},
          'default'                 =>  ["score" , "desc"]
      }
    }
  end
end
