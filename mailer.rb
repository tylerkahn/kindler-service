class Mailer
  require 'mail'
  require 'yaml'
  require './utilities.rb'


  def initialize

    $cfg = YAML.load_file("config.yml")

    smtp_options = Utilities.symbolize_keys($cfg['smtp_options'])
    pop_options = Utilities.symbolize_keys($cfg['pop_options'])

    Mail.defaults do
      delivery_method :smtp, smtp_options
      retriever_method :pop3, pop_options
    end
  end

  def fetch_mail
    Mail.find_and_delete
  end

  def deliver_notice(to_email, subj, notice)
    Mail.deliver do
      to to_email
      from "#{$cfg['email_name']} <#{$cfg['email_address']}>"
      subject subj

      text_part do
        body notice
      end

      html_part do
        content_type 'text/html; charset=UTF-8'
        body notice
      end
    end
  end

  def deliver_article(to_email, attachment_path)
    Mail.deliver do
      to to_email
      from "#{$cfg['email_name']} <#{$cfg['email_address']}>"
      add_file attachment_path
    end
  end

end
