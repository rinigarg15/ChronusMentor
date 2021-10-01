require_relative './../../test_helper.rb'

class DummyAbstractRequestController < ApplicationController
  include AbstractRequestConcern

  def update
    head :ok
  end

  def get_status_message
    abstract_request = AbstractRequest.find_by(id: params[:id])
    @message = get_status_based_message(abstract_request.status, params[:past])
    head :ok
  end

  private

  def fetch_request
    abstract_request = AbstractRequest.find_by(id: params[:id])
    handle_request_fetched_for_update(abstract_request, program_root_path)
  end
end

class AbstractRequestConcernTest < ActionController::TestCase
  tests DummyAbstractRequestController

  def test_update_invokes_fetch_request
    @controller.expects(:fetch_request).once

    current_user_is :f_mentor
    post :update, params: { id: 1, mentor_request: { status: AbstractRequest::Status::ACCEPTED }}
  end

  def test_get_status_message_active_request
    abstract_request = create_mentor_request

    @controller.expects(:fetch_request).never
    current_user_is abstract_request.mentor
    get :get_status_message, params: { id: abstract_request.id}
    assert_response :success
    assert_nil assigns(:message)
  end

  def test_get_status_message_accepted
    abstract_request = create_mentor_request(status: AbstractRequest::Status::ACCEPTED)

    current_user_is abstract_request.mentor
    get :get_status_message, params: { id: abstract_request.id}
    assert_response :success
    assert_equal "The request has been accepted", assigns(:message)
  end

  def test_get_status_message_rejected
    abstract_request = create_mentor_request(status: AbstractRequest::Status::REJECTED)

    current_user_is abstract_request.mentor
    get :get_status_message, params: { id: abstract_request.id, past: true}
    assert_response :success
    assert_equal "The request has already been declined.", assigns(:message)
  end

  def test_get_status_message_withdrawn
    abstract_request = create_mentor_request(status: AbstractRequest::Status::WITHDRAWN)

    current_user_is abstract_request.mentor
    get :get_status_message, params: { id: abstract_request.id}
    assert_response :success
    assert_equal "The request has been withdrawn", assigns(:message)
  end

  def test_get_status_message_closed
    abstract_request = create_mentor_request
    abstract_request.close_request!

    current_user_is abstract_request.mentor
    get :get_status_message, params: { id: abstract_request.id, past: true}
    assert_response :success
    assert_equal "The request has already been closed.", assigns(:message)
  end
end