require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, "secret"
end

root = File.expand_path("..", __FILE__)

get "/" do
  @files = Dir.glob(root + "/data/*").map { |path| File.basename(path) }
  erb :index
end

get "/:file_name" do
  path = root + "/data/" + params[:file_name]
  if File.file?(path)
    headers["Content-type"] = "text/plain"
    File.read(path)
  else
    session[:message] = "#{params[:file_name]} doesn't exist."
    redirect "/"
  end
end
