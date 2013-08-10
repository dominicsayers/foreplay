require 'foreplay'

describe Foreplay::Deploy do
	it "should check the config" do
		Foreplay::Deploy.start([:check, :production]).should eql('OK')
	end
end
