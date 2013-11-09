require 'spec_helper'
require 'foreplay'

describe Foreplay::Setup do
  before :each do
    `rm -f config/foreplay.yml`
  end

  it "should create a config file" do
    File.should_receive(:open)
    Foreplay::Setup.start
  end
end
