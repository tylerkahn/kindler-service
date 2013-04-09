require 'resque'
require 'uri'
require 'net/http'
require 'tempfile'
require 'digest/sha1'
require './mailer.rb'

$mailer = Mailer.new
$cfg = YAML::load_file('config.yml')

class FetchEmails
  @queue = :fetch_emails

  def self.perform
    $mailer.fetch_mail.each do |email|

      from_email = self.sender_email(email)
      urls = URI.extract(email.body.decoded, ["http","https"])

      if email.subject.empty?
        Resque.enqueue(EmailFailure, from_email,
                       "Couldn't find an email to send this to.")
      elsif urls.empty?
        Resque.enqueue(EmailFailure, from_email,
                       "Couldn't find a link to fetch for you.")
      else
        email.subject << "@kindle.com" unless /@/ =~ email.subject
        Resque.enqueue(FetchArticle, from_email, email.subject, urls.first)
      end
    end
  end

  def self.sender_email(email)
    email.sender.nil? ? email.from.to_a.first : email.sender.address
  end
end

class FetchArticle
  @queue = :fetch_articles

  def self.perform(from_email, to_email, article_url)
    out_path = File.join($cfg['files_path'], Digest::SHA1.hexdigest(article_url) << ".mobi")
    if not File.exists? out_path
      self.convert(from_email, article_url, out_path)
    end
    Resque.enqueue(EmailArticle, to_email, out_path)
    Resque.enqueue(EmailNotice, from_email, "Sent #{article_url}")
  end

  def self.convert(from_email, article_url, out_path)
    begin
      doc = self.get_article_details(article_url)
      Tempfile.open(["kindlerapp", ".html"]) do |f|
        f.write(doc["content"])
        f.flush
        self.run_convert(f.path, out_path, doc)
      end
    rescue
      Resque.enqueue(EmailFailure, from_email,
                     "Problem fetching the link, #{article_url}.")
      raise
    end
  end

  def self.run_convert(in_path, out_path, doc)
    title = "--title='#{doc["title"]}'"
    author = "--authors='#{doc["author"]}'"
    series = "--series='#{doc["domain"]}'"
    run_string = "ebook-convert #{in_path} #{out_path} #{title} #{author} #{series}"
    error = `#{run_string}`
    raise "#{run_string}\n#{error}\n#{doc}" if $?.exitstatus != 0
  end

  def self.get_article_details(article_url)
    uri = URI('https://www.readability.com/api/content/v1/parser')
    uri.query = URI.encode_www_form(:token => $cfg['readability_api_token'], :url => article_url)
    res = Net::HTTP.get_response(uri)
    if res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    else
      raise "Non-success HTTP code calling readability api with URL = #{uri.query}. #{res}"
    end
  end
end

class EmailNotice
  @queue = :email

  def self.perform(to_email, notice)
    $mailer.deliver_notice(to_email, "Kindler App", notice)
  end

end

class EmailFailure
  @queue = :email

  def self.perform(to_email, notice)
    $mailer.deliver_notice(to_email, "Kindler App Failure",  notice)
  end

end

class EmailArticle
  @queue = :email

  def self.perform(to_email, mobi_path)
    $mailer.deliver_article(to_email, mobi_path)
  end
end

class CleanUpOldFiles
  @queue = :email

  def self.perform
    Dir[File.join($cfg['files_path'], "*.mobi")].each do |f_path|
      n_days_ago = Time.now - ($cfg['cache_days'] * 24 * 60 * 60)
      comp = File.stat(f_path).mtime <=> n_days_ago
      if comp == -1 # created before n days ago
        File.delete(f_path)
      end
    end
  end
end
