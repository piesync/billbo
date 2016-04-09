class MailService
  def mail(invoice, pdf_path)
    mail = Mail.new
    mail.from = Configuration.mail_from
    mail.to = invoice.customer_email
    mail.subject = Configuration.mail_subject
    mail.add_file(pdf_path)

    mail.deliver!
  end
end
