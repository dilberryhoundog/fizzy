module SessionTestHelper
  def parsed_cookies
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
  end

  def sign_in_as(user)
    cookies[:session_token] = nil
    user = users(user) unless user.is_a? User
    post session_path, params: { email_address: user.email_address, password: "secret123456" }
    assert cookies[:session_token].present?
  end

  def sign_out
    delete session_path
    assert_not cookies[:session_token].present?
  end

  def with_current_user(user)
    user = users(user) unless user.is_a? User
    Current.session = Session.new(user: user)
    yield
  ensure
    Current.clear_all
  end
end
