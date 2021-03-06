
# Custom changes for the Hospital prototype.
# These are changes that are inconsistent with other prototype
# building types.
module Hospital
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')

    # add extra equipment for kitchen
    add_extra_equip_kitchen(model)

    system_to_space_map = define_hvac_system_map(building_type, climate_zone)

    hot_water_loop = nil
    model.getPlantLoops.sort.each do |loop|
      # If it has a boiler:hotwater, it is the correct loop
      unless loop.supplyComponents('OS:Boiler:HotWater'.to_IddObjectType).empty?
        hot_water_loop = loop
      end
    end
    if hot_water_loop
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          space_names = ['ER_Exam3_Mult4_Flr_1', 'OR2_Mult5_Flr_2', 'ICU_Flr_2', 'PatRoom5_Mult10_Flr_4', 'Lab_Flr_3']
          space_names.each do |space_name|
            add_humidifier(space_name, hot_water_loop, model)
          end
        when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
          space_names = ['ER_Exam3_Mult4_Flr_1', 'OR2_Mult5_Flr_2']
          space_names.each do |space_name|
            add_humidifier(space_name, hot_water_loop, model)
          end
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Could not find hot water loop to attach humidifier to.')
    end

    reset_kitchen_oa(model)
    model_update_exhaust_fan_efficiency(model)
    model_reset_or_room_vav_minimum_damper(prototype_input, model)

    # Modify the condenser water pump
    if template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      cw_pump = model.getPumpConstantSpeedByName('Condenser Water Loop Pump').get
      cw_pump_head_ft_h2o = 60.0
      cw_pump_head_press_pa = OpenStudio.convert(cw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
      cw_pump.setRatedPumpHead(cw_pump_head_press_pa)
    end

    return true
  end

  # add extra equipment for kitchen
  def add_extra_equip_kitchen(model)
    kitchen_space = model.getSpaceByName('Kitchen_Flr_5')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013'
          elec_equip_def1.setDesignLevel(915)
          elec_equip_def2.setDesignLevel(855)
        else
          elec_equip_def1.setDesignLevel(99_999.88)
          elec_equip_def2.setDesignLevel(99_999.99)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model_add_schedule(model, 'Hospital ALWAYS_ON'))
        elec_equip2.setSchedule(model_add_schedule(model, 'Hospital ALWAYS_ON'))
    end
  end

  def update_waterheater_loss_coefficient(model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          if water_heater.name.to_s.include?('Booster')
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053159296)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053159296)
          else
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(15.60100708)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(15.60100708)
          end
        end
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(model)
    return true
  end

  # add swh

  def reset_kitchen_oa(model)
    space_kitchen = model.getSpaceByName('Kitchen_Flr_5').get
    ventilation = space_kitchen.designSpecificationOutdoorAir.get
    ventilation.setOutdoorAirFlowperPerson(0)
    ventilation.setOutdoorAirFlowperFloorArea(0)
    case template
      when '90.1-2010', '90.1-2013'
        ventilation.setOutdoorAirFlowRate(3.398)
      when '90.1-2004', '90.1-2007', 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        ventilation.setOutdoorAirFlowRate(3.776)
    end
  end

  def model_update_exhaust_fan_efficiency(model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.16)
          exhaust_fan.setPressureRise(125)
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.338)
          exhaust_fan.setPressureRise(125)
        end
    end
  end

  def add_humidifier(space_name, hot_water_loop, model)
    space = model.getSpaceByName(space_name).get
    zone = space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model_add_schedule(model, 'Hospital MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(model_add_schedule(model, 'Hospital MaxRelHumSetSch'))
    zone.setZoneControlHumidistat(humidistat)

    model.getAirLoopHVACs.sort.each do |air_loop|
      if air_loop.thermalZones.include? zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(model)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100_000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject.get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(model)
        case template
          when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
            extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
            extra_elec_htg_coil.setName("#{space_name} Electric Htg Coil")
            extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
            extra_water_htg_coil.setName("#{space_name} Water Htg Coil")
            hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
            extra_elec_htg_coil.addToNode(supply_outlet_node)
            extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)
        humidity_spm.setControlZone(zone)
      end
    end
  end

  def model_add_daylighting_controls(model)
    space_names = ['Office1_Flr_5', 'Office3_Flr_5', 'Lobby_Records_Flr_1']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      space_add_daylighting_controls(space, false, false)
    end
  end

  def model_reset_or_room_vav_minimum_damper(prototype_input, model)
    case template
      when '90.1-2004', '90.1-2007'
        return true
      when '90.1-2010', '90.1-2013'
        model.getAirTerminalSingleDuctVAVReheats.sort.each do |airterminal|
          airterminal_name = airterminal.name.get
          if airterminal_name.include?('OR1') || airterminal_name.include?('OR2') || airterminal_name.include?('OR3') || airterminal_name.include?('OR4')
            airterminal.setZoneMinimumAirFlowMethod('Scheduled')
            airterminal.setMinimumAirFlowFractionSchedule(model_add_schedule(model, 'Hospital OR_MinSA_Sched'))
          end
        end
    end
  end

  def model_modify_oa_controller(model)
    model.getAirLoopHVACs.sort.each do |air_loop|
      oa_sys = air_loop.airLoopHVACOutdoorAirSystem.get
      oa_control = oa_sys.getControllerOutdoorAir
      case air_loop.name.get
        when 'VAV_ER', 'VAV_ICU', 'VAV_LABS', 'VAV_OR', 'VAV_PATRMS', 'CAV_1', 'CAV_2'
          oa_control.setEconomizerControlType('NoEconomizer')
      end
    end
  end
end
