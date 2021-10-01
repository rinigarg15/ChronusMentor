require_relative './../../../../test_helper.rb'
class CkeditorAssetExporterTest < ActiveSupport::TestCase
  
  def test_ckeditor_asset_export
    program = programs(:albers)
    create_ckasset

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)

    ckeditor_asset_exporter = CkeditorAssetExporter.new(program, program_exporter)
    ckeditor_asset_exporter.export

    ckeditor_assets = Ckeditor::Asset.where(:program_id => program.organization.id)
    exported_asset_ids = []
    exported_urls = []

    assert_equal ckeditor_asset_exporter.objs, ckeditor_assets
    assert_equal ckeditor_asset_exporter.file_name, 'ckeditor_asset'
    assert_equal ckeditor_asset_exporter.program, program
    assert_equal ckeditor_asset_exporter.parent_exporter, program_exporter
    assert File.exist?(solution_pack.base_path+'ckeditor_asset.csv')
    CSV.foreach(solution_pack.base_path+'ckeditor_asset.csv', headers: true) do |row|
      exported_asset_ids << row["id"].to_i
      exported_urls << row["url"]
    end
    assert_equal_unordered exported_asset_ids, ckeditor_assets.collect(&:id)
    assert_equal_unordered exported_urls, ckeditor_assets.map(&:path_for_ckeditor_asset)
    File.delete(solution_pack.base_path+'ckeditor_asset.csv') if File.exist?(solution_pack.base_path+'ckeditor_asset.csv')
  end

end