require './plugins/shows/lib/showname_parse'
require './plugins/shows/lib/showlist'

get "/show_list" do
  showsForDisplay = showList
  
  menu = haml :menu_partial, :locals => { :links => settings.menuLinks, :active_link => "Shows" }
  haml :show_list_partial, :views => "plugins/shows/views", :locals => {:menu => menu, :showsForDisplay => showsForDisplay}
end
