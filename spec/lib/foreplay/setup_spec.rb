require 'spec_helper'
require 'foreplay'

describe Foreplay::Setup do
  before :each do
    `rm -f config/foreplay.yml`
  end

  it 'should create a config file' do
    expect(File).to receive(:open)
    Foreplay::Setup.start
  end
end
