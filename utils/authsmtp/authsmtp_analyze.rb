require 'rubygems'
require 'mechanize'
require 'hpricot'
agent = WWW::Mechanize.new
page = agent.get 'http://control.authsmtp.com/signin.php'
form = page.forms.first
form.user_id = 'ac35265'
form.password = 'znqw4tdqj'

#Set no: of pages here
pages = 100
#Login to authsmtp
page1 = agent.submit(form,form.buttons.first)
url =  'http://control.authsmtp.com/mail-history.php'
k = 0

#LIST THE NUMBER OF PAGES HERE(for eg if we want hundred pages set k<100 or k<50 for 50 pages)
while k < pages
	page1 = agent.get url
	doc = Hpricot.parse(page1.body)

	#The pages are stored in dump folder for references
	dump = File.new("dump/page_"+k.to_s,"w")
	dump.write(doc)
	string1 = String.new

	#obtain date and time
	string1 = (doc/"td[@bgcolor = '#eeeeee']").inner_html
	date = Array.new
	id = Array.new
	from = Array.new
	to = Array.new
	subject = Array.new
	date = string1.split("Date / Time")
	date = date.collect{|d| d.split('&').first}
	date.delete_at(0)

	#The data's are stored in this file
	file = File.new("authsmtp.csv", "a+")
	string1 = (doc/"tr[@bgcolor = '#ddffcc']/td").inner_html

	#extract from coloumn
	from = string1.split("From")
	from.delete_at(0)
	from = from.collect{|d| d.split('To').first}
	stringto = string1.gsub(/To/,"\nTo")

	#extract to coloumn
	to = stringto.split("To")
	to = to.collect{|d| d.split('Subject').first}
	to.delete_at(0)
	
	# /\<font color\>(.*?)\<\/font\>/ =~ string1
	# extract subject coloumn
	string1.scan(/\<font color\>(.*?)\<\/font\>/i) do
	subject << $1
	end
	i=0
	id = Array.new
	#write into the file in the csv format
	while i < 20
		date[i] = date[i].gsub(":","")
		id = date[i].split(" ")                        
		from[i] =  from[i].gsub("&quot;","")
		from[i] =  from[i].gsub(":","")
		to[i] =  to[i].gsub(":","")
		output =  "\"" +id[0].to_s+"\""+","+ id[1].to_s + "," +"\"" +from[i]+"\""+","+"\""+to[i]+"\""+","+"\""+subject[i]+"\""+"\n"
 		puts output
		file.write(output)
		i += 1
	end
	k+=1
	#The url which should be followed next

	url = "http://control.authsmtp.com/mail-history.php?page="+k.to_s+"&err=0"
	dump.close
end # while k < 100

# Close the csv file
file.close

