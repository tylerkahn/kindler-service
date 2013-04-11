require 'rspec'
require_relative './spec_helper.rb'
require_relative '../jobs.rb'

describe FetchEmails, ".extract_details" do
  it "returns an empty hash when no details are specified" do
    body = <<-BODY
    http://nytim.es/some-article/about/whatever

    Sent from my iPhone
    BODY
    details = FetchEmails.extract_details(body)
    details.should == Hash.new
  end

  it "returns an empty hash when only the sentinal is present" do
    body = <<-BODY
    http://nytim.es/some-article/about/whatever

    Sent from my iPhone
    --*

    BODY
    details = FetchEmails.extract_details(body)
    details.should == Hash.new
  end

  it "returns a single detail when only one detail is present" do
    body = <<-BODY
    http://nytim.es/some-article/about/whatever

    Sent from my iPhone
    --*
    title: hello: world
    BODY
    details = FetchEmails.extract_details(body)
    details.should == {"title" => "hello: world"}
  end

  it "returns multiple details" do
    body = <<-BODY
    http://nytim.es/some-article/about/whatever

    Sent from my iPhone
    --*
    title: hello: world
    authors: An Author, Another Author
    BODY
    details = FetchEmails.extract_details(body)
    details.should == {
      "title" => "hello: world",
      "authors" => "An Author, Another Author"}
  end

  it "ignores extra sentinels" do
  body = <<-BODY
    http://nytim.es/some-article/about/whatever

    Sent from my iPhone
    --*
    hello: world
    --*
    title: hello: world
    authors: An Author, Another Author
    BODY
    details = FetchEmails.extract_details(body)
    details.should == {
      "title" => "hello: world",
      "authors" => "An Author, Another Author"}

  end
end

describe FetchArticle, ".merge_details" do
  it "should only merge non nil values" do
    new_details = FetchArticle.merge_details({
      "doc" => "Doc",
      "title" => "Auto Title",
      "author" => "Auto Author"
    },{
      "author" => "Author"
    })
    new_details.should == {
      "doc" => "Doc",
      "title" => "Auto Title",
      "author" => "Author"
    }
  end
end
