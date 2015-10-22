describe YAML do
  context '#escape' do
    it 'correctly escape a basic string' do
      expect(YAML.escape 'brian').to eq('brian')
    end

    it 'correctly escape a troublesome string' do
      expect(YAML.escape '{{moustache}}').to eq('"{{moustache}}"')
      expect(YAML.escape "Brian O'Brien").to eq("Brian O'Brien")
    end
  end
end
