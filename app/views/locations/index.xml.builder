xml.instruct! :xml, :version => "1.0"
xml.data do
  xml.locations do
    for location in @locations
      xml.location do
        xml.id location.id
        xml.name location.name
        xml.zoneNo location.zone_id
        xml.numMachines location.machines.size
        xml.lat location.lat
        xml.lon location.lon
      end
    end
  end

  xml.machines do
    for machine in @region.machines
      xml.machine do
        xml.id machine.id
        xml.name machine.name

        machine_counts = Hash.new
        @region.location_machine_xrefs.each do |lmx|
          (machine_counts[lmx.machine_id] ||= []) << lmx
        end

        xml.numLocations machine_counts[machine.id].size
      end
    end
  end
end
