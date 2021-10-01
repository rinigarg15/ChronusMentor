class ChronusDocs::AppDocument < ActiveRecord::Base

  self.table_name = "chronus_docs_app_documents"

  validates_presence_of :title, :description
end