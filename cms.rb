require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, "secret"
end

root = File.expand_path("..", __FILE__)

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def display_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

get "/" do
  @files = Dir.glob(root + "/data/*").map { |path| File.basename(path) }
  erb :index
end

get "/:file_name" do
  path = root + "/data/" + params[:file_name]
  if File.file?(path)
    display_file_content(path)
  else
    session[:message] = "#{params[:file_name]} doesn't exist."
    redirect "/"
  end
end

get "/:file_name/edit" do
  path = root + "/data/" + params[:file_name]
  @file_name = params[:file_name]
  @content = File.read(path)
  erb :edit
end

post "/:file_name" do
  path = root + "/data/" + params[:file_name]
  File.write(path, params[:content])
  session[:message] = "#{params[:file_name]} has been updated!"
  redirect "/"
end
