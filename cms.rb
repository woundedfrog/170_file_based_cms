require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, "secret"
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def display_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }
  erb :index
end

get "/new" do
  erb :new_document
end

post "/create" do
  title = params[:filename].to_s
  file_content = params[:content].to_s
  if !title.include?(".") || title.size == ''
    session[:message] = "A valid file-name and type is required!"
    status 422
    erb :new_document
  else
    path = File.join(data_path, title)
    File.write(path, file_content)
    session[:message] = "#{title} has been created!"
    redirect "/"
  end
end

get "/:file_name" do
  path = File.join(data_path, params[:file_name])
  if File.file?(path)
    display_file_content(path)
  else
    session[:message] = "#{params[:file_name]} doesn't exist."
    redirect "/"
  end
end

get "/:file_name/edit" do
  path = File.join(data_path, params[:file_name])
  @file_name = params[:file_name]
  @content = File.read(path)
  erb :edit
end

post "/:file_name" do
  path = File.join(data_path, params[:file_name])
  File.write(path, params[:content])
  session[:message] = "#{params[:file_name]} has been updated!"
  redirect "/"
end

get "/:file_name/delete" do
  path = File.join(data_path, params[:file_name])
  File.delete(path)
  session[:message] = "#{params[:file_name]} has been deleted!"
  redirect "/"
end
