require_relative './../../../test_helper.rb'
class CkeditorExportImportUtilsTest < ActiveSupport::TestCase

  def test_handle_ck_editor_export
    create_ckasset
    page = Page.create(program: programs(:albers), title: "Page", published: false, content: "Attachment: #{Ckeditor::Asset.last.url_content}", visibility: Page::Visibility::BOTH)
    sp = SolutionPack.new(program: programs(:albers), is_sales_demo: true)
    sp.initialize_solution_pack_for_export
    SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(programs(:albers), Page.last.content, sp)

    assert File.exist?(sp.ckeditor_base_path)
    assert File.exist?("#{sp.ckeditor_base_path}#{Ckeditor::Asset.last.id}")
    assert File.exist?("#{sp.ckeditor_base_path}#{Ckeditor::Asset.last.id}/#{Ckeditor::Asset.last.data_file_name}")
    #test when content is nil
    SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(programs(:albers), nil, sp)
  end

  def test_handle_ck_editor_export_without_ckeditor_asset
    create_ckasset
    page = Page.create(program: programs(:albers), title: "Page", published: false, content: "Attachment: #{Ckeditor::Asset.last.url_content}", visibility: Page::Visibility::BOTH)
    sp = SolutionPack.new(program: programs(:albers), is_sales_demo: true)
    sp.initialize_solution_pack_for_export
    sp.all_ck_assets = []
    SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(programs(:albers), Page.last.content, sp)

    assert File.exist?(sp.ckeditor_base_path)
    assert File.exist?("#{sp.ckeditor_base_path}#{Ckeditor::Asset.last.id}")
    assert_false File.exist?("#{sp.ckeditor_base_path}#{Ckeditor::Asset.last.id}/#{Ckeditor::Asset.last.data_file_name}")
    #test when content is nil
    SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(programs(:albers), nil, sp)
  end

  def test_scan_ckeditor_links
    asset_1 = create_ckasset(Ckeditor::AttachmentFile, "test_pic.png")
    asset_2 = create_ckasset(Ckeditor::Picture, "pic_2.png")
    content = "Attachment_1: #{asset_1.url_content}    Attachment_2: #{asset_2.url_content}"
    links = SolutionPack::CkeditorExportImportUtils.scan_ckeditor_links(programs(:albers).organization.url, content)

    assert_equal 2, links.size
    assert_equal ["ck_attachments", asset_1.id.to_s], links[0]
    assert_equal ["ck_pictures", asset_2.id.to_s], links[1]
  end

  def test_handle_ck_editor_import
    program = programs(:albers)
    asset_1 = create_ckasset(Ckeditor::AttachmentFile, "test_pic.png")
    asset_2 = create_ckasset(Ckeditor::Picture, "pic_2.png")
    asset_3 = create_ckasset(Ckeditor::AttachmentFile, "pic_2.png")
    old_asset_count = Ckeditor::Asset.count

    page_1 = Page.create(program: program, title: "Page", content: "Attachment_1: #{asset_1.url_content}    Attachment_2: #{asset_2.url_content}")
    page_2 = Page.create(program: program, title: "Page", content: "Attachment_3: #{asset_3.url_content}    Attachment_1: #{asset_1.url_content}")

    solution_pack = SolutionPack.new(:program => program)

    solution_pack.imported_ck_assets = {}
    solution_pack.ckeditor_old_base_url = "primary.#{DEFAULT_DOMAIN_NAME}"
    ckeditor_asset_column_names = ["id", "data_file_name", "login_required", "url"]
    ckeditor_asset_rows = [
      [asset_1.id.to_s, asset_1.data_file_name, asset_1.login_required.to_s, asset_1.path_for_ckeditor_asset],
      [asset_2.id.to_s, asset_2.data_file_name, asset_2.login_required.to_s, asset_2.path_for_ckeditor_asset]
    ]

    program = programs(:ceg)
    content_1 = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(program, solution_pack, page_1.content, ckeditor_asset_column_names, ckeditor_asset_rows)
    content_2 = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(program, solution_pack, page_2.content, ckeditor_asset_column_names, ckeditor_asset_rows)

    ckpic_1 = Ckeditor::Picture.last
    ckatt_1 = Ckeditor::AttachmentFile.last
    assert_equal old_asset_count + 2, Ckeditor::Asset.count
    assert_equal "pic_2.png", ckpic_1.data_file_name
    assert_equal "test_pic.png", ckatt_1.data_file_name
    assert_equal "Attachment_1: http://annauniv.#{DEFAULT_DOMAIN_NAME}/ck_attachments/#{ckatt_1.id}    Attachment_2: http://annauniv.#{DEFAULT_DOMAIN_NAME}/ck_pictures/#{ckpic_1.id}", content_1
    assert_equal "Attachment_3: #{SolutionPack::CkeditorExportImportUtils::INVALID_URL}    Attachment_1: http://annauniv.#{DEFAULT_DOMAIN_NAME}/ck_attachments/#{ckatt_1.id}", content_2

    #test when content is nil
    content_1 = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(program, solution_pack, nil, ckeditor_asset_column_names, ckeditor_asset_rows)
    assert_nil content_1
  end
end