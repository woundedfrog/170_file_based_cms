require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"
# url attribute scarping
require 'nokogiri'
require 'open-uri'
# -----
require 'fileutils'

configure do
  enable :sessions
  set :session_secret, "secret"
end

helpers do
  def full_file_name(file_path)
    file_path.split("/")
  end

  def get_file_name(file_path)
    full_file_name(file_path)[-1]
  end

  def get_folder_name(file_path)
    full_file_name(file_path)[-2]
  end
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
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

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
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

def user_signed_in?
  session.key?(:username)
end

def require_user_signin
  if user_signed_in? == false
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def file_type_is_supported?(file)
  [".rb", ".txt", ".md", ".jpg", ".png", ".gif"].include?(File.extname(file))
end

def edited?(path, content)
  File.read(path) != content
end

def get_file_name_parts(file)
    file_name = file
    extension = File.extname(file_name) # extract file extension
    basename = File.basename(file_name, extension) # extract file basename

    [basename, extension, file]
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }
  erb :index
end

get "/new" do
  require_user_signin

  erb :new_document
end

post "/create" do
  require_user_signin

  title = params[:filename].to_s
  file_content = params[:content].to_s

  if !file_type_is_supported?(title) || !title.include?(".") || title.size == ''
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

  basename, extension, file_name = get_file_name_parts(params[:file_name])

  path = File.join(data_path, file_name)

  if File.file?(path)
    display_file_content(path)
  else
    session[:message] = "#{params[:file_name]} doesn't exist."
    redirect "/"
  end
end

get "/data/:folder_name/:file_name" do

  basename, extension, file_name = get_file_name_parts(params[:file_name]) # FOR some reason this basename doesn't work properly here. I have to use the one below.
  basename = params[:folder_name] # extract file basename

  history_path = File.join(data_path + "/#{basename}/", file_name)

  if File.file?(history_path)
    display_file_content(history_path)
  else
    session[:message] = "#{params[:file_name]} doesn't exist."
    redirect "/"
  end
end

get "/:file_name/edit" do
  require_user_signin

  basename, extension, file_name = get_file_name_parts(params[:file_name])

  path = File.join(data_path, file_name)
  history_path = File.join(data_path + "/" + basename, "*")

  @file_history = Dir.glob(history_path).map { |file_path| file_path }
  @file_name = file_name
  @content = File.read(path)

  erb :edit
end

post "/:file_name" do
  require_user_signin

  basename, extension, file_name = get_file_name_parts(params[:file_name])

  new_path = File.join(data_path, basename) # save new directory to local var
  source_path = new_path + extension # save (original)source directory to local var
  version = (Time.now.to_s + "#{extension}").gsub(" ", "_") # gets timestamp of change

  if edited?(source_path, params[:content]) # checks if the file has been edited
    FileUtils.mkdir_p "#{new_path}" # creates new directory for history
    FileUtils.cp(source_path, "#{new_path}/#{version}") # copy's old(version) file to new directory
    File.write(source_path, params[:content]) # writes changes to current main file.
      session[:message] = "#{file_name} has been updated!"
      redirect "/"
  else
    status 422
    session[:message] = "No changes were detected"
    redirect "/#{file_name}/edit"
  end
end

post "/:file_name/delete" do
  require_user_signin

  path = File.join(data_path, params[:file_name])

  File.delete(path)

  session[:message] = "#{params[:file_name]} has been deleted!"
  redirect "/"
end

post "/:file_name/duplicate" do
  require_user_signin
  file_lenth = params[:file_name].size + 1

  path = File.join(data_path, params[:file_name])

  File.open(path, "r") do |file|
    File.write(path.insert(-file_lenth, "copy_"), file.read)
  end

  session[:message] = "#{params[:file_name]} has been duplicated!"
  redirect "/"
end

get "/upload/image" do
  require_user_signin
  erb :upload
end

post "/upload/image" do
  url = params[:upload]
  doc = Nokogiri::HTML(open(url))
  attr_tag = doc.css("img").map{ |i| i["title"] }.compact.first

  if attr_tag.nil?
    attr_tag = url.split("/").last[0..5]
  end
  img_name = "img_" + attr_tag.gsub(" ", "_").downcase + ".md"

  link = "![#{img_name}](#{url})"

  path = File.join(data_path, img_name)
  File.write(path, link)

  session[:message] = "Image #{img_name} has been successfully uploaded!"
  redirect '/'
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username = params[:username]
  password = params[:password]

  if valid_credentials?(username, password)
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials!"
    status 422
    erb :signin
  end
end

get "/users/signup" do
  erb :signup
end

post "/users/signup" do
  username = params[:username]
  password = params[:password]

  if username == "" || password == ""
    session[:message] = "Please enter a username and password"
    status 422
    erb :signup
  else
    user_file = File.read("users.yml")
    data = YAML.load(user_file)
    data[username] = BCrypt::Password.create(password).to_s
    File.write("users.yml", YAML.dump(data))
    redirect "/users/signin"
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end
