# Use this hook to configure ckeditor
if Object.const_defined?("Ckeditor")
  require  "./lib/ckeditor/hooks/chronus"

  Ckeditor.setup do |config|
    # ==> ORM configuration
    # Load and configure the ORM. Supports :active_record (default), :mongo_mapper and
    # :mongoid (bson_ext recommended) by default. Other ORMs may be
    # available as additional gems.
    require "ckeditor/orm/active_record"

    # Allowed image file types for upload.
    # Set to nil or [] (empty array) for all file types
    # By default: %w(jpg jpeg png gif tiff)
    # config.image_file_types = ["jpg", "jpeg", "png", "gif", "tiff"]

    # Allowed attachment file types for upload.
    # Set to nil or [] (empty array) for all file types
    # By default: %w(doc docx xls odt ods pdf rar zip tar tar.gz swf)
    # config.attachment_file_types = ["doc", "docx", "xls", "odt", "ods", "pdf", "rar", "zip", "tar", "swf"]

    # Setup authorization to be run as a before filter
    # By default: there is no authorization.
    # config.authorize_with :cancan
    #TODO-CR: allow to destroy self's assets
    config.authorize_with :chronus

    config.current_user_method do
        wob_member
    end

    # asset_compile.rake file will copy the non-digested assets
    config.run_on_precompile = false

    # Asset model classes
    # config.picture_model { Ckeditor::Picture }
    # config.attachment_file_model { Ckeditor::AttachmentFile }

    # Reduce precompile time by limiting languages, plugins
    #config.assets_languages = ['en', 'fr-ca']
    #config.assets_plugins = [dialogui,dialog,about,a11yhelp,dialogadvtab,basicstyles,bidi,blockquote,clipboard,button,panelbutton,panel,floatpanel,colorbutton,colordialog,templates,menu,contextmenu,div,resize,toolbar,elementspath,list,indent,enterkey,entities,popup,filebrowser,find,fakeobjects,flash,floatingspace,listblock,richcombo,font,forms,format,htmlwriter,horizontalrule,iframe,wysiwygarea,image,smiley,justify,link,liststyle,magicline,maximize,newpage,pagebreak,pastetext,pastefromword,preview,print,removeformat,save,selectall,showblocks,showborders,sourcearea,specialchar,menubutton,scayt,stylescombo,tab,table,tabletools,undo,wsc]
    #config.assets_plugins += ['mediaembed']
    # TODO-CR: Find out plugins and languages needed

    # Paginate assets
    # By default: 24
    # config.default_per_page = 24

    # Customize ckeditor assets path
    # By default: nil
    # config.asset_path = "http://www.example.com/assets/ckeditor/"
  end
end
