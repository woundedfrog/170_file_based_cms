ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_fetch_document_list
    get "/changes.txt"
    assert_includes last_response.body, "There were so many changes"
  end

  def test_invalid_document
    get "/invalid_document.txt"

    assert_equal 302, last_response.status
    get last_response["location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "invalid_document.txt doesn't exist"

    get "/"
    refute_includes last_response.body, "invalid_document.txt doesn't exist"
  end

  def test_markdown_documents
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Text to HTML Markdown</h1>"
  end
end
