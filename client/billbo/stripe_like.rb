module Billbo
  module StripeLike

    # From https://github.com/stripe/stripe-ruby/blob/master/lib/stripe.rb#L111.
    def self.request(options)
      begin
        response = execute_request(options)
      rescue SocketError => e
        handle_restclient_error(e)
      rescue NoMethodError => e
        # Work around RestClient bug
        if e.message =~ /\WRequestFailed\W/
          e = APIConnectionError.new('Unexpected HTTP response code')
          handle_restclient_error(e)
        else
          raise
        end
      rescue RestClient::ExceptionWithResponse => e
        if rcode = e.http_code and rbody = e.http_body
          handle_api_error(rcode, rbody)
        else
          handle_restclient_error(e)
        end
      rescue RestClient::Exception, Errno::ECONNREFUSED => e
        handle_restclient_error(e)
      end

      parse(response)
    end

    def self.execute_request(opts)
      RestClient::Request.execute(opts)
    end

    def self.parse(response)
      begin
        # Would use :symbolize_names => true, but apparently there is
        # some library out there that makes symbolize_names not work.
        response = JSON.parse(response.body)
      rescue JSON::ParserError
        raise general_api_error(response.code, response.body)
      end

      Stripe::Util.symbolize_names(response)
    end

    def self.general_api_error(rcode, rbody)
      Stripe::APIError.new("Invalid response object from API: #{rbody.inspect} " +
                   "(HTTP response code was #{rcode})", rcode, rbody)
    end

    def self.handle_api_error(rcode, rbody)
      begin
        error_obj = JSON.parse(rbody)
        error_obj = Stripe::Util.symbolize_names(error_obj)
        error = error_obj[:error] or raise Stripe::StripeError.new # escape from parsing

      rescue JSON::ParserError, Stripe::StripeError => e
        raise general_api_error(rcode, rbody)
      end

      case rcode
      when 400, 404
        raise invalid_request_error error, rcode, rbody, error_obj
      when 401
        raise authentication_error error, rcode, rbody, error_obj
      when 402
        raise card_error error, rcode, rbody, error_obj
      else
        raise api_error error, rcode, rbody, error_obj
      end

    end

    def self.invalid_request_error(error, rcode, rbody, error_obj)
      Stripe::InvalidRequestError.new(error[:message], error[:param], rcode,
                              rbody, error_obj)
    end

    def self.authentication_error(error, rcode, rbody, error_obj)
      Stripe::AuthenticationError.new(error[:message], rcode, rbody, error_obj)
    end

    def self.card_error(error, rcode, rbody, error_obj)
      Stripe::CardError.new(error[:message], error[:param], error[:code],
                    rcode, rbody, error_obj)
    end

    def self.api_error(error, rcode, rbody, error_obj)
      Stripe::APIError.new(error[:message], rcode, rbody, error_obj)
    end

    def self.handle_restclient_error(e)
      case e
      when RestClient::ServerBrokeConnection, RestClient::RequestTimeout
        message = "Could not connect to Stripe (#{@api_base}). " +
          "Please check your internet connection and try again. " +
          "If this problem persists, you should check Stripe's service status at " +
          "https://twitter.com/stripestatus, or let us know at support@stripe.com."

      when RestClient::SSLCertificateNotVerified
        message = "Could not verify Stripe's SSL certificate. " +
          "Please make sure that your network is not intercepting certificates. " +
          "(Try going to https://api.stripe.com/v1 in your browser.) " +
          "If this problem persists, let us know at support@stripe.com."

      when SocketError
        message = "Unexpected error communicating when trying to connect to Stripe. " +
          "You may be seeing this message because your DNS is not working. " +
          "To check, try running 'host stripe.com' from the command line."

      else
        message = "Unexpected error communicating with Stripe. " +
          "If this problem persists, let us know at support@stripe.com."

      end

      raise Stripe::APIConnectionError.new(message + "\n\n(Network error: #{e.message})")
    end
  end
end
