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
    assert_includes last_response.body, "many changes"
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

  def test_document_editing
    get "/about.md/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_document_updates
    get "/testing_text.txt"
    original_contents = last_response.body

    post "/testing_text.txt", content: original_contents + "Added content: content testing text"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "testing_text.txt has been updated"

    get "/testing_text.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "content testing text"
  end
end
