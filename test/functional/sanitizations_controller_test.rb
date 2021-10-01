require_relative "./../test_helper.rb"

class SanitizationsControllerTest < ActionController::TestCase
  def test_compare_content_before_and_after_sanitize_with_version_v1
    current_program_is :albers
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    post :compare_content_before_and_after_sanitize, params: { :content => "Hello <script>alert(test)</script>", :format => :js}
    assert_response :success
    assert "", response.body
  end

  def test_compare_content_before_and_after_sanitize_with_version_v2
    current_program_is :albers
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    post :compare_content_before_and_after_sanitize, params: { :content => "Hello <script>alert(test)</script>", :format => :js}
    assert_response :success
    assert_match(/<strong>&lt;script&gt;<\/strong>alert\(test\)<strong>&lt;\/script&gt;<\/strong>/, response.body)
  end

  def test_compare_content_attribute_before_and_after_sanitize_with_version_v2
    current_program_is :albers
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    post :compare_content_before_and_after_sanitize, params: { :content => "Hello <a href='javascript:alert(1)'>hack</a> and ok", :format => :js}
    assert_response :success
    json_obj = JSON(response.body)
    assert_equal "Hello <a>hack</a> and ok", json_obj["sanitized_content"]
    assert_match " <li class=\"del\"><del>Hello &lt;a<strong> href=&quot;javascript:alert(1)&quot;</strong>&gt;hack&lt;/a&gt; and ok</del></li>    <li class=\"ins\"><ins>Hello &lt;a&gt;hack&lt;/a&gt; and ok</ins></li>", json_obj["diff"]
  end

  def test_compare_content_style_attribute_before_and_after_sanitize_with_version_v2
    current_program_is :albers
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    user_content = <<-CONTENT
      <div style="color: red">case1</div>
      <div style="color: red;">case2</div>
      <div style="color: red; background-color: yellow;">case3</div>
      <div style="color: red;;;;;;">case4</div>
      <div style="color: red;            ;">case5</div>
      <div style="color:red;background-color:yellow;">case6</div>
      <div style="color: red; src: url(javascript:alert(1)); background-color: yellow;">case7</div>
      <div style="color: red; someattr: someval; background-color: yellow;">case8</div>
      <div style="color: red; background-color: yellow;">case9</div><badtag />
      <div style="   ">case10</div>
      <div style=";">case11</div>
      <div style=";;">case12</div>
      <div style=";;   ">case13</div>
      <div style="   ;  ;  ">case14</div>
    CONTENT
    cleaned_content = <<-CONTENT
      <div style="color: red;">case1</div>
      <div style="color: red;">case2</div>
      <div style="color: red; background-color: yellow;">case3</div>
      <div style="color: red;">case4</div>
      <div style="color: red;">case5</div>
      <div style="color: red; background-color: yellow;">case6</div>
      <div style="color: red; background-color: yellow;">case7</div>
      <div style="color: red; background-color: yellow;">case8</div>
      <div style="color: red; background-color: yellow;">case9</div>
      <div style>case10</div>
      <div style>case11</div>
      <div style>case12</div>
      <div style>case13</div>
      <div style>case14</div>
    CONTENT
    
    post :compare_content_before_and_after_sanitize, params: { content: user_content, format: :js}
    assert_response :success
    json_obj = JSON(response.body)
    assert_equal cleaned_content, json_obj["sanitized_content"]
    assert_match "<div class=\"diff\">  <ul>    <li class=\"del\"><del>      &lt;div style=&quot;color: red; <strong>src: url(javascript:alert(1)); </strong>background-color: yellow;&quot;&gt;case7&lt;/div&gt;</del></li>    <li class=\"del\"><del>      &lt;div style=&quot;color: red; <strong>someattr: someval; </strong>background-color: yellow;&quot;&gt;case8&lt;/div&gt;</del></li>    <li class=\"del\"><del>      &lt;div style=&quot;color: red; background-color: yellow;&quot;&gt;case9&lt;/div&gt;<strong>&lt;badtag&gt;&lt;/badtag&gt;</strong></del></li>    <li class=\"ins\"><ins>      &lt;div style=&quot;color: red; background-color: yellow;&quot;&gt;case7&lt;/div&gt;</ins></li>    <li class=\"ins\"><ins>      &lt;div style=&quot;color: red; background-color: yellow;&quot;&gt;case8&lt;/div&gt;</ins></li>    <li class=\"ins\"><ins>      &lt;div style=&quot;color: red; background-color: yellow;&quot;&gt;case9&lt;/div&gt;</ins></li>  </ul></div>", json_obj["diff"]
  end

  def test_no_issue_cases
    current_program_is :albers
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    user_content = <<-CONTENT
      <div style="">case1</div>
      <div style="          ">case2</div>
      <div style=";">case3</div>
      <div style="color: red">case4</div>
      <div style="color: red;">case5</div>
      <div style="   color: red">case6</div>
      <div style="   color   : red">case7</div>
      <div style="   color   :   red">case8</div>
      <div style="   color   :   red   ">case9</div>
      <div style="   color: red;">case10</div>
      <div style="   color   : red;">case11</div>
      <div style="   color   :   red;">case12</div>
      <div style="   color   :   red   ;">case13</div>
      <div style="   color   :   red   ; background-color: yellow">case13</div>
      <div style="   color   :   red   ; background-color: yellow;">case14</div>
      <div style=";;;;;;;;;">case15</div>
      <div style="    ;;;;;;;;;">case15</div>
      <div style=";;;;;;;;;    ">case15</div>
      <div style="    ;;;;     ;;;;;   ">case15</div>
    CONTENT

    post :compare_content_before_and_after_sanitize, params: { content: user_content, format: :js}
    assert_response :success
    json_obj = JSON(response.body)
    assert_match "", json_obj["diff"]
  end

  def test_compare_content_body_onload_before_and_after_sanitize_with_version_v2
    current_program_is :albers
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    post :compare_content_before_and_after_sanitize, params: { :content => "<body onload='alert(1)'>Hello <a href='http://www.chronus.com'>link</a></body>", :format => :js}
    assert_response :success
    json_obj = JSON(response.body)
    assert_equal "Hello <a href=\"http://www.chronus.com\">link</a>\n", json_obj["sanitized_content"]
    assert_match "<li class=\"del\"><del><strong>&lt;body&gt;</strong>Hello &lt;a href=&quot;http://www.chronus.com&quot;&gt;link&lt;/a&gt;</del></li>    <li class=\"del\"><del><strong>&lt;/body&gt;</strong></del></li>    <li class=\"del\"><del><strong></strong></del></li>    <li class=\"ins\"><ins>Hello &lt;a href=&quot;http://www.chronus.com&quot;&gt;link&lt;/a&gt;</ins></li>", json_obj["diff"]
  end

  def test_preview_sanitized_content_for_admin_with_version_v1
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    post :preview_sanitized_content, params: { :content => "Hello <script>alert(test)</script>", :format => :js}
    assert_response :success
    assert_match /<script>alert\(test\)<\\\/script>/, response.body
  end

  def test_preview_sanitized_content_for_admin_with_version_v2
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    post :preview_sanitized_content, params: { :content => "Hello <script>alert(test)</script>", :format => :js}
    assert_response :success
    assert_match /<script>alert\(test\)<\\\/script>/, response.body
  end

  def test_preview_sanitized_content_for_user_with_version_v1
    current_user_is :f_mentor
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    post :preview_sanitized_content, params: { :content => "Hello <script>alert(test)</script>", :format => :js}
    assert_response :success
    assert_match /<script>alert\(test\)<\\\/script>/, response.body
  end

  def test_sanitize_encoded_tags_in_urls_without_vulnerable_content
    current_program_is :albers
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    user_content = <<-CONTENT
      <a href="{{url_invitation}}">link1</a>
      <a href="chronus.com">{{url_invitation}}</a>
      <a href="{{url_invitation">link3</a>
      <a href="url_invitation}}">link4</a>
      <a href="{url_invitation}">link5</a>
    CONTENT
    cleaned_content = <<-CONTENT
      <a href="{{url_invitation}}">link1</a>
      <a href="chronus.com">{{url_invitation}}</a>
      <a href="%7B%7Burl_invitation">link3</a>
      <a href="url_invitation%7D%7D">link4</a>
      <a href="%7Burl_invitation%7D">link5</a>
    CONTENT
    
    post :compare_content_before_and_after_sanitize, params: { content: user_content, format: :js}
    assert_response :success
    json_obj = JSON(response.body)
    assert_equal cleaned_content, json_obj["sanitized_content"]
    assert_match "", json_obj["diff"]
  end

  def test_sanitize_encoded_tags_in_urls_with_vulnerable_content
    current_program_is :albers
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    user_content = <<-CONTENT
      <a href="{{url_invitation}}">link1</a>
      <a href="chronus.com">{{url_invitation}}</a>
      <a href="{{url_invitation">link3</a>
      <a href="url_invitation}}">link4</a>
      <Font color = "red"><strong>January 19, 2016</strong></Font>
      <a href="{url_invitation}">link5</a>
    CONTENT
    cleaned_content = <<-CONTENT
      <a href="{{url_invitation}}">link1</a>
      <a href="chronus.com">{{url_invitation}}</a>
      <a href="%7B%7Burl_invitation">link3</a>
      <a href="url_invitation%7D%7D">link4</a>
      <strong>January 19, 2016</strong>
      <a href="%7Burl_invitation%7D">link5</a>
    CONTENT
    
    post :compare_content_before_and_after_sanitize, params: { content: user_content, format: :js}
    assert_response :success
    json_obj = JSON(response.body)
    assert_equal cleaned_content, json_obj["sanitized_content"]
    assert_match "<div class=\"diff\">  <ul>    <li class=\"del\"><del>      &lt;<strong>font color=&quot;red&quot;&gt;&lt;</strong>strong&gt;January 19, 2016&lt;/strong&gt;<strong>&lt;/font&gt;</strong></del></li>    <li class=\"ins\"><ins>      &lt;strong&gt;January 19, 2016&lt;/strong&gt;</ins></li>  </ul></div>", json_obj["diff"]
  end

  def test_preview_sanitized_content_for_user_with_version_v2
    current_user_is :f_mentor
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    post :preview_sanitized_content, params: { :content => "Hello <script>alert(test)</script>", :format => :js}
    assert_response :success
    assert_no_match /<script>alert\(test\)<\\\/script>/, response.body
  end
end