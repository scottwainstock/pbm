require 'spec_helper'

describe Api::V1::RegionsController, type: :request do
  before(:each) do
    @portland = FactoryBot.create(:region, id: 555, name: 'portland', motd: 'foo', full_name: 'Portland', lat: 12, lon: 13)
    @la = FactoryBot.create(:region, name: 'la', full_name: 'Los Angeles', lat: 14, lon: 15)

    FactoryBot.create(:user, region: @portland, email: 'portland@admin.com', is_super_admin: 1)
    FactoryBot.create(:user, region: @la, email: 'la@admin.com')
    @user = FactoryBot.create(:user, email: 'foo@bar.com', authentication_token: '1G8_s7P-V-4MGojaKD7a', username: 'ssw')
  end

  describe '#location_and_machine_counts' do
    before(:each) do
      @pdx_location = FactoryBot.create(:location, region: @portland)
      @pdx_location_two = FactoryBot.create(:location, region: @portland)
      @la_location = FactoryBot.create(:location, region: @la)
      @machine = FactoryBot.create(:machine)
      @machine_two = FactoryBot.create(:machine)

      FactoryBot.create(:location_machine_xref, machine_id: @machine.id, location_id: @pdx_location.id)
      FactoryBot.create(:location_machine_xref, machine_id: @machine_two.id, location_id: @pdx_location.id)
      FactoryBot.create(:location_machine_xref, machine_id: @machine.id, location_id: @pdx_location_two.id)
      FactoryBot.create(:location_machine_xref, machine_id: @machine.id, location_id: @la_location.id)
    end

    it 'tells you how many total locations and machines are tracked on pbm' do
      get '/api/v1/regions/location_and_machine_counts.json'

      expect(response).to be_successful
      parsed_body = JSON.parse(response.body)

      expect(parsed_body['num_locations']).to eq(3)
      expect(parsed_body['num_lmxes']).to eq(4)
    end

    it 'tells you how many total locations and machines are in a specific region' do
      get '/api/v1/regions/location_and_machine_counts.json', params: { region_name: @portland.name }

      expect(response).to be_successful
      parsed_body = JSON.parse(response.body)

      expect(parsed_body['num_locations']).to eq(2)
      expect(parsed_body['num_lmxes']).to eq(3)
    end

    it 'throws an error if name does not correspond to a region' do
      get '/api/v1/regions/location_and_machine_counts.json', params: { region_name: 'foo' }

      expect(JSON.parse(response.body)['errors']).to eq('This is not a valid region.')
    end
  end

  describe '#does_region_exist' do
    it 'tells you if name is a valid region' do
      FactoryBot.create(:region, id: 6, name: 'clark', motd: 'mine', lat: 12.0, lon: 13.0, full_name: 'Clarky')

      get '/api/v1/regions/does_region_exist.json', params: { name: 'clark' }
      expect(response).to be_successful
      parsed_body = JSON.parse(response.body)
      expect(parsed_body.size).to eq(1)

      region = parsed_body['region']

      expect(region['id']).to eq(6)
      expect(region['name']).to eq('clark')
      expect(region['motd']).to eq('mine')
      expect(region['lat']).to eq('12.0')
      expect(region['lon']).to eq('13.0')
      expect(region['full_name']).to eq('Clarky')
    end

    it 'throws an error if name does not correspond to a region' do
      get '/api/v1/regions/does_region_exist.json', params: { name: 'foo' }

      expect(JSON.parse(response.body)['errors']).to eq('This is not a valid region.')
    end
  end

  describe '#closest_by_lat_lon' do
    it 'sends back closest region' do
      FactoryBot.create(:region, name: 'not portland', lat: 122.0, lon: 13.0)

      get '/api/v1/regions/closest_by_lat_lon.json', params: { lat: 12.1, lon: 13.0 }
      expect(response).to be_successful
      parsed_body = JSON.parse(response.body)
      expect(parsed_body.size).to eq(1)

      region = parsed_body['region']

      expect(region['id']).to eq(555)
      expect(region['name']).to eq('portland')
      expect(region['motd']).to eq('foo')
      expect(region['lat']).to eq('12.0')
      expect(region['lon']).to eq('13.0')
      expect(region['full_name']).to eq('Portland')
    end

    it 'throws an error if no regions are within 250 miles' do
      get '/api/v1/regions/closest_by_lat_lon.json', params: { lat: 120.0, lon: 13.0 }

      expect(JSON.parse(response.body)['errors']).to eq('No regions within 250 miles.')
    end
  end

  describe '#show' do
    it 'sends back region metadata' do
      get "/api/v1/regions/#{@portland.id}.json"
      expect(response).to be_successful
      parsed_body = JSON.parse(response.body)
      expect(parsed_body.size).to eq(1)

      region = parsed_body['region']

      expect(region['name']).to eq('portland')
      expect(region['motd']).to eq('foo')
      expect(region['lat']).to eq('12.0')
      expect(region['lon']).to eq('13.0')
      expect(region['full_name']).to eq('Portland')
    end

    it 'throws an error if the region does not exist' do
      get '/api/v1/regions/-123.json'

      expect(JSON.parse(response.body)['errors']).to eq('Failed to find region')
    end
  end

  describe '#contact' do
    before(:each) do
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries = []
    end
    after(:each) do
      ActionMailer::Base.deliveries.clear
    end
    it 'throws an error if the region does not exist' do
      post '/api/v1/regions/contact.json', params: { region_id: -1, user_email: 'foo@bar.com', user_token: '1G8_s7P-V-4MGojaKD7a' }

      expect(JSON.parse(response.body)['errors']).to eq('Failed to find region')
    end

    it 'errors when required fields are not sent' do
      expect(ActionMailer::Base.deliveries.count).to eq(0)
      post '/api/v1/regions/contact.json', params: { region_id: @la.id.to_s, user_email: 'foo@bar.com', user_token: '1G8_s7P-V-4MGojaKD7a' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)['errors']).to eq('A message (and email if not logged in) is required.')

      expect(ActionMailer::Base.deliveries.count).to eq(0)
      post '/api/v1/regions/contact.json', params: { region_id: @la.id.to_s, message: '', user_email: 'foo@bar.com', user_token: '1G8_s7P-V-4MGojaKD7a' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)['errors']).to eq('A message (and email if not logged in) is required.')

      expect(ActionMailer::Base.deliveries.count).to eq(0)
      post '/api/v1/regions/contact.json', params: { region_id: @la.id.to_s, message: 'hello', user_email: '' }
      expect(response).to be_successful
      expect(JSON.parse(response.body)['errors']).to eq('A message (and email if not logged in) is required.')
    end

    it 'emails region admins with incoming message and account info if logged in' do
      expect do
        post '/api/v1/regions/contact.json', params: { region_id: @la.id.to_s, email: 'email', message: 'message', name: 'name', user_email: 'foo@bar.com', user_token: '1G8_s7P-V-4MGojaKD7a' }, headers: { HTTP_USER_AGENT: 'cleOS' }
        expect(response).to be_successful
        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq('Pinball Map - Message (Los Angeles)')
        expect(email.from).to eq(['admin@pinballmap.com'])
        expect(email.to).to eq(['la@admin.com'])
        expect(email.cc).to eq(['portland@admin.com'])

        expect(JSON.parse(response.body)['msg']).to eq('Thanks for the message.')
        expect(UserSubmission.all.count).to eq(1)
        expect(UserSubmission.first.submission_type).to eq(UserSubmission::CONTACT_US_TYPE)
      end.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it 'emails region admins with incoming message when user is not logged in' do
      expect do
        post '/api/v1/regions/contact.json', params: { region_id: @la.id.to_s, email: 'email', message: 'message', name: 'name' }, headers: { HTTP_USER_AGENT: 'cleOS' }
        expect(response).to be_successful
        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq('Pinball Map - Message (Los Angeles)')
        expect(email.from).to eq(['admin@pinballmap.com'])
        expect(email.to).to eq(['la@admin.com'])
        expect(email.cc).to eq(['portland@admin.com'])

        expect(JSON.parse(response.body)['msg']).to eq('Thanks for the message.')
        expect(UserSubmission.all.count).to eq(1)
        expect(UserSubmission.first.submission_type).to eq(UserSubmission::CONTACT_US_TYPE)
      end.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it 'emails super admins when lat/lon is null or no regions are within lat/lon bounding boxes' do
      expect do
        post '/api/v1/regions/contact.json', params: { region_id: nil, lat: nil, lon: nil, email: 'email', message: 'message', name: 'name', user_email: 'foo@bar.com', user_token: '1G8_s7P-V-4MGojaKD7a' }, headers: { HTTP_USER_AGENT: 'cleOS' }
        expect(response).to be_successful
        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq('Pinball Map - Message')
        expect(email.from).to eq(['admin@pinballmap.com'])
        expect(email.to).to eq(['portland@admin.com'])

        expect(JSON.parse(response.body)['msg']).to eq('Thanks for the message.')
        expect(UserSubmission.all.count).to eq(1)
        expect(UserSubmission.first.region_id).to be_nil
      end.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it 'finds closest region by lat/lon' do
      expect do
        post '/api/v1/regions/contact.json', params: { region_id: nil, lat: 12, lon: 13, email: 'email', message: 'message', name: 'name', user_email: 'foo@bar.com', user_token: '1G8_s7P-V-4MGojaKD7a' }, headers: { HTTP_USER_AGENT: 'cleOS' }
        expect(response).to be_successful
        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq('Pinball Map - Message (Portland)')
        expect(email.from).to eq(['admin@pinballmap.com'])
        expect(email.to).to eq(['portland@admin.com'])
      end.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it 'emails region admins with incoming message - notifies if sent from staging server' do
      expect do
        host! 'pbmstaging.com'
        post '/api/v1/regions/contact.json', params: { region_id: @la.id.to_s, email: 'email', message: 'message', name: 'name', user_email: 'foo@bar.com', user_token: '1G8_s7P-V-4MGojaKD7a' }
        expect(response).to be_successful
        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq('(STAGING) Pinball Map - Message (Los Angeles)')
      end.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end
end
