  #encoding : utf-8
class Globalization::PseudolocalizeUtils

  def self.pseudolocalize_file(src_file, target_file, target_locale="af")
    strings = YAML.load_file(src_file)
    new_strings = Globalization::PseudolocalizeUtils.transform(strings)
    new_strings = Hash[target_locale.to_s => new_strings['en']]
    File.open( target_file, 'w+' ) do |f|
      f.puts new_strings.to_yaml
    end
  end

  def self.pseudolocalize_for(target_path, locales)
    all_en_yml_file = "#{Rails.root.to_s}/tmp/phrase.en.yml"
    Globalization::PhraseappUtils.merge_locales_to_single_yaml(nil, all_en_yml_file)
    locales.each do |locale|
      target_file_path = File.join(target_path, "test_phrase.#{locale.to_s}.yml")
      Globalization::PseudolocalizeUtils.pseudolocalize_file(all_en_yml_file, target_file_path, locale)
    end
    FileUtils.rm all_en_yml_file
  end

private

  def self.pseudolocalize(str)
    n = 0
    newstr = ""
    if !str.nil?
      str.each_char { |c|
        if c == "{"
          n += 1
        elsif c == "}"
          n -= 1
        end
        if n < 1
          newstr += c.tr("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", 
                     "áƀčďéƒǧĥíʲǩłɱɳóƿƣřšťůνŵхýžÁƁČĎÉƑǦĤÍǰǨŁϺЍÓРƢŘŠŤŮѶŴХÝŽ")
        else
          newstr += c
        end
      }
      return "[[ #{newstr} ]]"
    end
  end

  def self.transform(p, parent_key = "") 
    if p.kind_of?(Hash)
      newhash = Hash.new
      p.each { |key, value| 
        new_parent_key =  parent_key  + ( parent_key.empty? ? key : ".#{key}" )
        if ( new_parent_key == "en.time.formats" || new_parent_key == "en.date.formats" )
          newhash[key] = value
        else
          newhash[key] = Globalization::PseudolocalizeUtils.transform(value, new_parent_key)
        end
        }
      return newhash
    elsif p.kind_of?(String)
      return Globalization::PseudolocalizeUtils.pseudolocalize(p)
    elsif p.kind_of?(Array)
      a=[]
      p.each do |arr| 
      a.push Globalization::PseudolocalizeUtils.pseudolocalize(arr) 
    end
      return a
    else
      return "#{p}!"
    end
  end

end