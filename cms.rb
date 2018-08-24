require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

root = File.expand_path("..", __FILE__)

get "/" do
  @files = Dir.glob(root + "/data/*").map { |path| File.basename(path) }
  erb :index
end

get "/:file_name" do
  path = root + "/data/" + params[:file_name]

  headers["Content-type"] = "text/plain"
  File.read(path)
end
