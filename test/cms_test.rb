ENV["RACK_ENV"] = "test"

require "fileutils"
require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)

    create_document "about.md", "#Text to be tested"
    create_document "changes.txt", "So many changes were made that it's crazy"
    create_document "history.txt"
    create_document "test.txt"
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
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
  #
  def test_markdown_documents
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Text to be tested</h1>"
  end

  def test_document_editing
    get "/about.md/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_document_updates
    post "/changes.txt", content: "content testing text"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "content testing text"
  end

  def test_view_new_document_form
  get "/new"

  assert_equal 200, last_response.status
  assert_includes last_response.body, "<input"
  assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_new_document
    post "/create", filename: "test.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been created"

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/create", filename: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A valid file-name and type is required!"
  end

  def test_deleting_document
    post "/test.txt/delete"

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been deleted"

    get "/"
    refute_includes last_response.body, "test.txt"
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end
