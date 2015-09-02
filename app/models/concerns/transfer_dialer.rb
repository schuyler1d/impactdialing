class TransferDialer
  attr_reader :transfer, :transfer_attempt, :caller_session, :call, :voter

private
  def warm_transfer?
    types = [
      transfer_attempt.transfer_type,
      transfer.transfer_type
    ]
    types.map!{|str| str.try(:downcase)}
    types.include? Transfer::Type::WARM
  end

  def transfer_attempt_dialed(response)
    if response.error?
      attempt_attrs = {status: CallAttempt::Status::FAILED}
    else
      attempt_attrs = {sid: response.call_sid}
      activate_transfer
    end
    transfer_attempt.update_attributes(attempt_attrs)
  end

  def activate_transfer
    if warm_transfer?
      RedisCallerSession.activate_transfer(caller_session.session_key, transfer_attempt.session_key)
    end
  end

  def transfer_attempt_connected
    transfer_attempt.update_attribute(:connecttime, Time.now)
  end

  def create_transfer_attempt
    transfer.transfer_attempts.create({
      session_key: generate_session_key,
      campaign_id: caller_session.campaign_id,
      status: CallAttempt::Status::RINGING,
      caller_session_id: caller_session.id,
      transfer_type: transfer.transfer_type
    })
  end

  def generate_session_key
    return secure_digest(Time.now, (1..10).map{ rand.to_s })
  end

  def secure_digest(*args)
    return Digest::SHA1.hexdigest(args.flatten.join('--'))
  end

  def hangup_xml
    return Twilio::TwiML::Response.new {|r| r.Hangup }.text
  end

  def lead_call
    return nil if caller_session.nil?
    @lead_call ||= caller_session.dialed_call
  end

public
  def initialize(transfer)
    @transfer = transfer
  end

  def deactivate_transfer(session_key)
    RedisCallerSession.deactivate_transfer(session_key)
  end

  def dial(caller_session)
    @caller_session   = caller_session
    @transfer_attempt = create_transfer_attempt

    lead_call.storage[:transfer_attempt_id] = @transfer_attempt.id

    deactivate_transfer(caller_session.session_key)
    # twilio makes synchronous callback requests so redis flag must be set
    # before calls are made if the flags are to handle callback requests
    params   = Providers::Phone::Call::Params::Transfer.new(transfer, :connect, transfer_attempt, lead_call)
    response = Providers::Phone::Call.make(params.from, params.to, params.url, params.params, Providers::Phone.default_options)
    transfer_attempt_dialed(response)

    return {
      type: transfer.transfer_type,
      status: transfer_attempt.status
    }
  end

  def end
  end

  def connect(transfer_attempt)
    @transfer_attempt = transfer_attempt
    @caller_session = transfer_attempt.caller_session

    transfer_attempt_connected

    # todo: refactor workflow to queue call redirects and return TwiML faster

    # Publish transfer_type
    caller_session.publish('transfer_connected', {type: transfer_attempt.transfer_type})
    # Update current callee call with Twilio to transfers#callee, which renders conference xml
    params = Providers::Phone::Call::Params::Transfer.new(transfer, :callee, transfer_attempt, lead_call)
    callee_redirect_response = Providers::Phone::Call.redirect(params.call_sid, params.url, Providers::Phone.default_options)

    unless callee_redirect_response.error?
      if warm_transfer?
        # Keep the caller on the conference.
        # Update current caller call with Twilio to transfers#caller, which renders conference xml
        params = Providers::Phone::Call::Params::Transfer.new(transfer, :caller, transfer_attempt, lead_call)
        resp = Providers::Phone::Call.redirect(params.call_sid, params.url, Providers::Phone.default_options)
        # todo: handle failures of above redirect
        caller_session.publish("warm_transfer",{})
      else
        ##
        # This redirect is needed in case the caller is/was in a transfer conference.
        # todo: fix double pause requests. The Dial:action for Transfer#caller is pause_caller_url so this results in 2 req to /pause.
        Providers::Phone::Call.redirect_for(caller_session, :pause)
        # todo: handle failures of above redirect
        caller_session.publish("cold_transfer",{})
      end

      phone_params = Providers::Phone::Call::Params::Transfer.new(transfer_attempt.transfer, :disconnect, transfer_attempt, lead_call)

      xml = Twilio::TwiML::Response.new do |twiml|
        # The action url for Dial will be called by Twilio when the dialed party hangs up
        twiml.Dial :hangupOnStar => 'false', :action => phone_params.url, :record => caller_session.campaign.account.record_calls do |dial|
          dial.Conference transfer_attempt.session_key, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET', :beep => false, :endConferenceOnExit => false
        end
      end
    else
      # no point in transferring if the lead cannot join
      deactivate_transfer(caller_session.session_key)
      Providers::Phone::Call.redirect_for(caller_session, :pause)

      xml = Twilio::TwiML::Response.new do |twiml|
        twiml.Hangup
      end
    end

    return xml.text
  end
end
