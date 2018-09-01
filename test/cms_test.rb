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

  def session
    last_request.env["rack.session"]
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

  def test_invalid_document_not_found
    get "/invalid_document.txt"

    assert_equal 302, last_response.status
    assert_equal "invalid_document.txt doesn't exist.", session[:message]
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
    assert_equal "changes.txt has been updated!", session[:message]

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
    assert_equal "test.txt has been created!", session[:message]

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
    assert_equal "test.txt has been deleted!", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    get "/", {}, {"rack.session" => { username: "admin"} }
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    get last_response["Location"]

    assert_nil session[:username]
    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Sign In"
  end

# These two tests are doing the same thing, but the 2nd one is more natural.
  def test_sets_session_value
    post "/users/signin", username: "admin", password: "secret"
    get last_response["Location"]

    get "/"
    assert_equal "admin", session[:username]
  end

  def test_index_as_signed_in_user
    get "/", {}, {"rack.session" => { username: "admin"} }
  end
# ...end...

  def teardown
    FileUtils.rm_rf(data_path)
  end
end
