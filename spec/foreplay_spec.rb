require 'foreplay'

describe Foreplay::Config do
	it "should check the config" do
		Foreplay::Config.check.should eql('OK')
	end
end
