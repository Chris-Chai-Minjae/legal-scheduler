# @TASK T3.1 - Keywords controller test
# @SPEC REQ-SET-01: GIVEN-WHEN-THEN scenarios

require "test_helper"

class KeywordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  # Scenario 1: 키워드 추가
  test "should add custom keyword" do
    # GIVEN: 사용자가 키워드 설정 페이지에 있을 때
    get keywords_path
    assert_response :success

    # WHEN: "공판" 키워드를 입력하고 추가 버튼을 클릭하면
    assert_difference("@user.keywords.count", 1) do
      post keywords_path, params: { keyword: { keyword: "공판" } }
    end

    # THEN: 키워드가 목록에 추가된다
    assert_redirected_to keywords_path
    follow_redirect!
    assert_select "div#keywords-list", text: /공판/
  end

  # Scenario 2: 키워드 삭제
  test "should delete keyword" do
    # GIVEN: "재판" 키워드가 목록에 있을 때
    keyword = @user.keywords.create!(keyword: "재판", is_active: true)

    # WHEN: 삭제 버튼을 클릭하면
    assert_difference("@user.keywords.count", -1) do
      delete keyword_path(keyword)
    end

    # THEN: 키워드가 목록에서 제거된다
    assert_redirected_to keywords_path
    assert_nil Keyword.find_by(id: keyword.id)
  end

  # Scenario 3: 키워드 활성/비활성 토글
  test "should toggle keyword active state" do
    # GIVEN: 활성화된 키워드가 있을 때
    keyword = @user.keywords.create!(keyword: "변론", is_active: true)

    # WHEN: 비활성화 버튼을 클릭하면
    post toggle_keyword_path(keyword)

    # THEN: 키워드가 비활성 상태로 변경된다
    assert_not keyword.reload.is_active
    assert_redirected_to keywords_path
  end

  test "should create default keywords on user creation" do
    # GIVEN: 새 사용자가 생성될 때
    new_user = User.create!(
      email_address: "test@example.com",
      password: "Password123"
    )

    # THEN: 기본 키워드가 자동으로 생성된다
    assert_equal 3, new_user.keywords.count
    assert_includes new_user.keywords.pluck(:keyword), "변론"
    assert_includes new_user.keywords.pluck(:keyword), "검찰조사"
    assert_includes new_user.keywords.pluck(:keyword), "재판"

    # 모든 기본 키워드가 활성 상태여야 함
    assert new_user.keywords.all?(&:is_active)
  end

  test "should prevent duplicate keywords" do
    # GIVEN: "변론" 키워드가 이미 존재할 때
    @user.keywords.create!(keyword: "변론", is_active: true)

    # WHEN: 같은 키워드를 추가하려고 하면
    assert_no_difference("@user.keywords.count") do
      post keywords_path, params: { keyword: { keyword: "변론" } }
    end

    # THEN: 에러가 발생한다
    assert_response :unprocessable_entity
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "Password123" }
  end
end
