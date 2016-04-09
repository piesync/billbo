require 'spec_helper'

describe MailService do
  let(:mail_service) { MailService.new }

  describe '#mail' do
    it 'mails the invoice' do
      invoice = Invoice.new(
        number: '2016001',
        customer_email: 'john.doe@customer.com'
      )

      pdf_path = File.expand_path('../test.pdf', __FILE__)

      mail_service.mail(invoice, pdf_path)

      deliveries = Mail::TestMailer.deliveries
      deliveries.length.must_equal 1
      mail = deliveries.first
      mail.to.must_equal ['john.doe@customer.com']
      mail.from.must_equal ['billing@acme.org']
      mail.subject.must_equal 'Your invoice!'
      mail.attachments.count.must_equal 1

      attachment = mail.attachments.first
      attachment.mime_type.must_equal 'application/pdf'
    end
  end
end
