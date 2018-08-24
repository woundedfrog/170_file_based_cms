require "sinatra"
require "sinatra/reloader"

get "/" do
  @greeting = "Getting started."
end
