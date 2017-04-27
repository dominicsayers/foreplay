describe Foreplay::Engine::Secrets::Location do
  context 'YAML safe-load' do
    it 'allows default and symbol handling' do
      date_string = '2013-09-25 16:00:00 +0800'
      date_value = date_string.to_time
      location = Foreplay::Engine::Secrets::Location.new 'url', 'production'

      expect(location).to receive(:raw_secrets).and_return(
        <<-YAML.gsub('          ', '')
          ---
          default: &default
            default_key: default_value

          production:
            <<: *default
            production_key: :production_value
            production_date: #{date_string}
        YAML
      )

      expect(location.all_secrets).to eq(
        'default' => { 'default_key' => 'default_value' },
        'production' => {
          'default_key' => 'default_value',
          'production_key' => :production_value,
          'production_date' => date_value
        }
      )
    end
  end
end
